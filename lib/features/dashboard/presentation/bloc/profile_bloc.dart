import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:dio/dio.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/network/token_manager.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/origin_resolver.dart' show resolveOrigin;
import 'profile_event.dart';
import 'profile_state.dart';

class ProfileBloc extends Bloc<ProfileEvent, ProfileState> {
  final ApiClient apiClient;
  final TokenManager tokenManager;
  final String defaultSuffix;

  ProfileBloc({required this.apiClient, required this.tokenManager, required this.defaultSuffix}) : super(ProfileInitial()) {
    on<LoadProfile>(_onLoadProfile);
    on<RefreshProfile>(_onRefreshProfile);
  }

  Future<void> _onLoadProfile(LoadProfile event, Emitter<ProfileState> emit) async {
    emit(ProfileLoading());
    try {
      final subDomain = await tokenManager.readSubDomain();
      final origin = resolveOrigin(subDomain, defaultSuffix);
      final options = origin != null ? Options(headers: {'Origin': origin}) : null;

      final resp = await apiClient.get(ApiConstants.userProfile, options: options);
      final status = resp.statusCode ?? 0;
      if (status >= 200 && status < 300) {
        if (resp.data is Map<String, dynamic>) {
          final raw = resp.data as Map<String, dynamic>;

          Map<String, dynamic>? userMap;
          if (raw.containsKey('user') && raw['user'] is Map<String, dynamic>) {
            userMap = Map<String, dynamic>.from(raw['user'] as Map);
          } else if (raw.containsKey('data') && raw['data'] is Map<String, dynamic>) {
            final dataNode = raw['data'] as Map<String, dynamic>;
            if (dataNode.containsKey('user') && dataNode['user'] is Map<String, dynamic>) {
              userMap = Map<String, dynamic>.from(dataNode['user'] as Map);
            } else {
              userMap = Map<String, dynamic>.from(dataNode);
            }
          } else {
            final likelyUserKeys = ['user_id', 'user_full_name', 'email', 'username', 'name'];
            final containsUserKey = raw.keys.any((k) => likelyUserKeys.contains(k));
            if (containsUserKey) userMap = Map<String, dynamic>.from(raw);
          }

          if ((raw.containsKey('success') && raw['success'] == false) && userMap == null) {
            final message = (raw['message'] ?? raw['error'] ?? 'Failed to load profile').toString();
            emit(ProfileError(message));
            return;
          }

          if (userMap != null) {
            final name = (userMap['user_full_name'] ?? userMap['name'] ?? userMap['fullName'] ?? userMap['full_name'] ?? userMap['username'] ?? userMap['email']) as String?;
            emit(ProfileLoaded(name ?? 'User'));
            return;
          }

          emit(ProfileError('Unexpected response shape (no user)'));
          return;
        }

        emit(ProfileError('Unexpected response shape'));
        return;
      }

      emit(ProfileError('Failed to load profile: ${resp.statusMessage}'));
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      final data = e.response?.data;
      String msg;
      if (data is Map<String, dynamic>) {
        msg = (data['message'] ?? data['error'] ?? data['msg'] ?? data.toString()).toString();
      } else if (data is String) {
        msg = data;
      } else {
        msg = e.message ?? 'Network error';
      }
      emit(ProfileError('Network error: ${status ?? ''} $msg'));
    } catch (e) {
      emit(ProfileError(e.toString()));
    }
  }

  Future<void> _onRefreshProfile(RefreshProfile event, Emitter<ProfileState> emit) async {
    // For now, re-use load logic. If desired, add different behavior.
    await _onLoadProfile(LoadProfile(), emit);
  }
}
