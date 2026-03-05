import 'package:dio/dio.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/utils/logger.dart';
import '../models/auth_response_model.dart';
import '../../../../core/network/origin_resolver.dart' show resolveOrigin;

class AuthRemoteDataSource {
  final Dio dio;
  final String defaultSubDomain;

  AuthRemoteDataSource({required this.dio, required this.defaultSubDomain});

  /// Calls login endpoint. Expects response with access_token and optional refresh_token.
  Future<AuthResponseModel> login({required String email, required String password, required String subDomain, required String captchaToken}) async {
    final origin = resolveOrigin(subDomain, defaultSubDomain);

    try {
      // Debug: log resolved origin and whether Authorization header exists on the Dio instance
      try {
        final hasAuth = dio.options.headers.containsKey('Authorization') || (dio.interceptors.isNotEmpty);
        Logger.d('Login: resolved Origin=$origin, Dio has Authorization header? $hasAuth');
      } catch (_) {}

      final resp = await dio.post(
        ApiConstants.login,
        data: {'email': email, 'password': password, 'captchaToken': captchaToken},
        options: origin != null ? Options(headers: {'Origin': origin}) : null,
      );

      final status = resp.statusCode ?? 0;
      if (status >= 200 && status < 300) {
        if (resp.data is Map<String, dynamic>) {
          return AuthResponseModel.fromJson(resp.data as Map<String, dynamic>);
        }
        // unexpected body
        Logger.e('Login: unexpected response shape', resp.data);
        throw ApiException('Invalid server response', statusCode: status);
      }

      // Non 2xx
      Logger.e('Login failed with status: $status, data: ${resp.data}');
      final message = resp.data is Map ? (resp.data['message'] ?? resp.data.toString()) : resp.statusMessage ?? 'Login failed';
      throw ApiException(message.toString(), statusCode: status);
    } on DioException catch (e) {
      // Network / timeout / server error
      final status = e.response?.statusCode;
      final data = e.response?.data;
      Logger.e('Login request failed', e, e.stackTrace);
      if (status != null) {
        final message = data is Map ? (data['message'] ?? data.toString()) : data?.toString() ?? e.message;
        throw ApiException(message.toString(), statusCode: status);
      }
      throw ApiException(e.message ?? 'Network error');
    } catch (e, st) {
      Logger.e('Unexpected error in login', e, st);
      throw ApiException('Unexpected error: $e');
    }
  }

  /// Calls refresh endpoint with refresh token. Expects new access token and optional refresh token.
  Future<AuthResponseModel> refresh({required String refreshToken}) async {
    try {
      final resp = await dio.post(
        ApiConstants.refreshToken,
        data: {'refresh_token': refreshToken},
      );

      final status = resp.statusCode ?? 0;
      if (status >= 200 && status < 300) {
        if (resp.data is Map<String, dynamic>) {
          return AuthResponseModel.fromJson(resp.data as Map<String, dynamic>);
        }
        Logger.e('Refresh: unexpected response shape', resp.data);
        throw ApiException('Invalid server response', statusCode: status);
      }

      Logger.e('Refresh failed with status: $status, data: ${resp.data}');
      final message = resp.data is Map ? (resp.data['message'] ?? resp.data.toString()) : resp.statusMessage ?? 'Refresh failed';
      throw ApiException(message.toString(), statusCode: status);
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      final data = e.response?.data;
      Logger.e('Refresh request failed', e, e.stackTrace);
      if (status != null) {
        final message = data is Map ? (data['message'] ?? data.toString()) : data?.toString() ?? e.message;
        throw ApiException(message.toString(), statusCode: status);
      }
      throw ApiException(e.message ?? 'Network error');
    } catch (e, st) {
      Logger.e('Unexpected error in refresh', e, st);
      throw ApiException('Unexpected error: $e');
    }
  }

  /// Calls logout endpoint. POST with empty body. Optionally include Origin header built from subDomain when provided.
  Future<void> logout({String? subDomain}) async {
    final origin = resolveOrigin(subDomain, defaultSubDomain);
    try {
      // Debug: log origin and Authorization presence before sending logout
      try {
        final authHeader = dio.options.headers['Authorization'];
        final hasAuth = authHeader != null || dio.interceptors.isNotEmpty;
        String masked = 'none';
        if (authHeader is String && authHeader.startsWith('Bearer ')) {
          final token = authHeader.substring(7);
          masked = token.length > 8 ? token.substring(0, 8) + '...' : token;
        }
        Logger.d('Logout: resolved Origin=$origin, Authorization header present? $hasAuth, tokenPrefix=$masked');
      } catch (_) {}

      final resp = await dio.post(
        ApiConstants.logout,
        data: {},
        options: origin != null ? Options(headers: {'Origin': origin}) : null,
      );

      final status = resp.statusCode ?? 0;
      if (status >= 200 && status < 300) return;

      Logger.e('Logout failed with status: $status, data: ${resp.data}');
      final message = resp.data is Map ? (resp.data['message'] ?? resp.data.toString()) : resp.statusMessage ?? 'Logout failed';
      throw ApiException(message.toString(), statusCode: status);
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      final data = e.response?.data;
      Logger.e('Logout request failed', e, e.stackTrace);
      if (status != null) {
        final message = data is Map ? (data['message'] ?? data.toString()) : data?.toString() ?? e.message;
        throw ApiException(message.toString(), statusCode: status);
      }
      throw ApiException(e.message ?? 'Network error');
    } catch (e, st) {
      Logger.e('Unexpected error in logout', e, st);
      throw ApiException('Unexpected error: $e');
    }
  }
}
