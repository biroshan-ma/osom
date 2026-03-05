import 'dart:async';

import 'package:dio/dio.dart';
import 'token_manager.dart';
import '../utils/logger.dart';

/// Dio interceptor that attaches access token and handles 401 by attempting a
/// refresh via the provided [onRefreshToken] callback. It prevents multiple
/// simultaneous refresh attempts and queues awaiting error handlers via a
/// shared [_refreshFuture].
class AuthInterceptor extends Interceptor {
  final TokenManager tokenManager;

  /// Called to perform a refresh. Should return true on success.
  final Future<bool> Function()? onRefreshToken;

  /// Called when the system must force logout (e.g., refresh failed or no
  /// refresh token available).
  final void Function()? onLogout;

  /// The Dio instance used to replay requests after a successful refresh.
  final Dio dio;

  AuthInterceptor({
    required this.tokenManager,
    required this.dio,
    this.onRefreshToken,
    this.onLogout,
  });

  Future<bool>? _refreshFuture;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    try {
      final access = await tokenManager.readAccessToken();
      if (access != null && access.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $access';
      }
    } catch (e, st) {
      Logger.e('Failed to attach access token', e, st);
    }

    return handler.next(options);
  }

  @override
  void onError(DioError err, ErrorInterceptorHandler handler) async {
    final response = err.response;

    // If not 401 or no response, just forward
    if (response?.statusCode != 401) {
      return handler.next(err);
    }

    final options = err.requestOptions;

    // Prevent infinite loop: if this request already retried, bail out
    if (options.extra['retried'] == true) {
      return handler.next(err);
    }

    final hasRefresh = await tokenManager.hasRefreshToken();
    if (!hasRefresh) {
      // No refresh token -> force logout
      Logger.i('401 received and no refresh token available. Forcing logout.');
      await tokenManager.clearAll();
      onLogout?.call();
      return handler.next(err);
    }

    try {
      // If a refresh is already in progress, await it
      if (_refreshFuture != null) {
        Logger.i('Refresh in progress - awaiting existing refresh future');
        final success = await _refreshFuture!;
        if (!success) {
          await tokenManager.clearAll();
          onLogout?.call();
          return handler.next(err);
        }
      } else {
        // Start refresh
        if (onRefreshToken == null) {
          Logger.e('onRefreshToken callback is not provided');
          await tokenManager.clearAll();
          onLogout?.call();
          return handler.next(err);
        }

        Logger.i('Starting token refresh');
        _refreshFuture = _safeRefresh();
        final success = await _refreshFuture!;
        _refreshFuture = null;

        if (!success) {
          Logger.i('Refresh failed - forcing logout');
          await tokenManager.clearAll();
          onLogout?.call();
          return handler.next(err);
        }
      }

      // At this point, refresh succeeded; retry original request with new token
      final newAccess = await tokenManager.readAccessToken();
      if (newAccess == null) {
        Logger.e('Refresh succeeded but no access token found');
        await tokenManager.clearAll();
        onLogout?.call();
        return handler.next(err);
      }

      // Mark retried to avoid loops
      options.extra['retried'] = true;
      options.headers['Authorization'] = 'Bearer $newAccess';

      // Replay the original request using the provided Dio instance
      final responseRetry = await dio.fetch(options);

      return handler.resolve(responseRetry);
    } catch (e, st) {
      Logger.e('Error while handling 401 in interceptor', e, st);
      await tokenManager.clearAll();
      onLogout?.call();
      return handler.next(err);
    }
  }

  Future<bool> _safeRefresh() async {
    try {
      final result = await onRefreshToken!();
      return result;
    } catch (e, st) {
      Logger.e('Refresh callback threw', e, st);
      return false;
    }
  }
}

