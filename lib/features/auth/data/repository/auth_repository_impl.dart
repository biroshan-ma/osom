import 'dart:async';

import 'package:dio/dio.dart';

import '../../domain/entities/auth_entity.dart';
import '../../domain/repository/auth_repository.dart';
import '../datasource/auth_remote_datasource.dart';
import '../../../../core/network/token_manager.dart';
import '../../../../core/utils/logger.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource remote;
  final TokenManager tokenManager;
  final String? defaultSubDomain;

  final StreamController<bool> _authStateController = StreamController<bool>.broadcast();

  AuthRepositoryImpl({required this.remote, required this.tokenManager, this.defaultSubDomain});

  /// Stream that emits `false` when a forced logout is required.
  Stream<bool> get authStateChanges => _authStateController.stream;

  @override
  Future<AuthEntity> login({required String email, required String password, required String subDomain, required String captchaToken}) async {
    final resp = await remote.login(email: email, password: password, subDomain: subDomain, captchaToken: captchaToken);
    // Save access token and optional refresh token
    await tokenManager.saveAccessToken(resp.accessToken);
    if (resp.refreshToken != null) {
      await tokenManager.saveRefreshToken(resp.refreshToken!);
    }

    // Persist the subDomain the user used for login so logout and other calls can reuse it.
    if (subDomain.isNotEmpty) {
      await tokenManager.saveSubDomain(subDomain); // save raw subDomain
    }

    return resp;
  }

  @override
  Future<void> logout() async {
    // Read persisted sub-domain and access token for debugging before logout request
    final persisted = await tokenManager.readSubDomain();
    final access = await tokenManager.readAccessToken();
    Logger.i('Attempting logout. Access token present=${access != null && access.isNotEmpty}, persistedSubDomain=$persisted, defaultSubDomain=$defaultSubDomain');

    // Decide which sub-domain to send to the remote: prefer persisted, fallback to defaultSubDomain
    String? subDomainToUse;
    if (persisted != null && persisted.isNotEmpty) {
      subDomainToUse = persisted;
    } else if (defaultSubDomain != null && defaultSubDomain!.isNotEmpty) {
      // Only use defaultSubDomain directly if it's a raw tenant (no leading '.' or '/' or scheme)
      final looksLikeSuffix = defaultSubDomain!.startsWith('.') || defaultSubDomain!.startsWith('/') || defaultSubDomain!.contains('{sub-domain}') || defaultSubDomain!.startsWith('http://') || defaultSubDomain!.startsWith('https://');
      if (!looksLikeSuffix) {
        subDomainToUse = defaultSubDomain;
      } else {
        // Do not pass suffix/template directly as subDomain (would create malformed origin like http://.localhost)
        subDomainToUse = null;
      }
    } else {
      subDomainToUse = null;
    }

    try {
      // Attempt to notify server (logout endpoint) before clearing local state. If remote call fails, still clear local tokens.
      await remote.logout(subDomain: subDomainToUse);
    } on DioException catch (dioErr) {
      // Log response details to help debugging
      final status = dioErr.response?.statusCode;
      final data = dioErr.response?.data;
      Logger.e('Logout API error: status=$status, data=$data', dioErr, dioErr.stackTrace);
      // continue to clear local tokens to avoid inconsistent authenticated state
    } catch (e, st) {
      Logger.e('Unexpected error during logout', e, st);
    }

    await tokenManager.clearAll();
    _authStateController.add(false);
  }

  @override
  Future<bool> refreshToken() async {
    final refresh = await tokenManager.readRefreshToken();
    if (refresh == null || refresh.isEmpty) return false;

    try {
      final resp = await remote.refresh(refreshToken: refresh);
      // Save new tokens
      await tokenManager.saveAccessToken(resp.accessToken);
      if (resp.refreshToken != null) {
        await tokenManager.saveRefreshToken(resp.refreshToken!);
      }
      return true;
    } catch (e) {
      await tokenManager.clearAll();
      _authStateController.add(false);
      return false;
    }
  }

  /// Called by interceptor when it needs to force logout (e.g., refresh failed or no refresh).
  Future<void> forceLogout() async {
    await tokenManager.clearAll();
    _authStateController.add(false);
  }
}
