import 'package:dio/dio.dart';

import '../../domain/entities/user_entity.dart';
import '../../domain/repository/user_repository.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/origin_resolver.dart' show resolveOrigin;
import '../../../../core/network/token_manager.dart';

class UserRepositoryImpl implements UserRepository {
  final ApiClient apiClient;
  final TokenManager tokenManager;
  final String defaultSuffix;

  UserRepositoryImpl({required this.apiClient, required this.tokenManager, required this.defaultSuffix});

  @override
  Future<UserEntity> me() async {
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

        if (userMap != null) {
          // attempt to extract default branch from feature_roles
          int? discoveredBranchId;
          try {
            // Use the first entry of feature_roles (index 0) as the default branch as requested.
            if (userMap['feature_roles'] is List && (userMap['feature_roles'] as List).isNotEmpty) {
              final first = (userMap['feature_roles'] as List).first;
              if (first is Map<String, dynamic> && first.containsKey('branch')) {
                final b = first['branch'];
                final bid = b is int ? b : int.tryParse(b?.toString() ?? '');
                if (bid != null) discoveredBranchId = bid;
              }
            }
          } catch (_) {}

          // persist discoveredBranchId as default selected branch if none already selected
          try {
            final existing = await tokenManager.readSelectedBranchId();
            if (existing == null && discoveredBranchId != null) {
              await tokenManager.saveSelectedBranchId(discoveredBranchId);
            }
          } catch (_) {}

          // Use UserModel to parse but avoid importing model directly to keep boundaries clear in this small example.
          return UserEntity(
            id: userMap['user_id'] is int ? userMap['user_id'] as int : int.tryParse(userMap['user_id']?.toString() ?? '') ?? 0,
            fullName: (userMap['user_full_name'] ?? userMap['name'] ?? userMap['fullName'] ?? userMap['full_name'] ?? userMap['username'] ?? userMap['email']) as String,
            role: (userMap['role'] ?? '') as String,
            email: (userMap['email'] ?? '') as String,
            isActive: (userMap['is_active'] ?? true) as bool,
            phoneNumber: userMap['phone_number']?.toString(),
            notificationToken: userMap['notification_token']?.toString(),
            featureRoles: [],
          );
        }

        throw Exception('Unexpected response shape (no user)');
      }

      throw Exception('Unexpected response shape');
    }

    if (status == 401) {
      throw DioException(requestOptions: resp.requestOptions, response: resp);
    }

    throw Exception('Failed to load profile: ${resp.statusMessage}');
  }
}
