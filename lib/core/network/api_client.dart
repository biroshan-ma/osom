import 'package:dio/dio.dart';
import '../constants/api_constants.dart';
import 'dio_interceptor.dart';
import 'token_manager.dart';
import '../network/origin_resolver.dart' as origin_resolver;

/// Central API client used by the app. All requests should go through this.
class ApiClient {
  final Dio _dio;

  ApiClient._(this._dio);

  factory ApiClient({
    required TokenManager tokenManager,
    Future<bool> Function()? onRefresh,
    void Function()? onLogout,
    String? baseUrl,
    String? deviceId,
    Map<String, String>? extraHeaders,
    String? defaultSuffix,
  }) {
    final base = baseUrl ?? ApiConstants.baseUrl;

    final baseHeaders = {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'X-Client-Type': 'mobile',
      'X-Device-Id': deviceId ?? 'device-unknown',
    };

    if (extraHeaders != null) {
      baseHeaders.addAll(extraHeaders);
    }

    final baseOptions = BaseOptions(
      baseUrl: base,
      connectTimeout: const Duration(milliseconds: 15000),
      receiveTimeout: const Duration(milliseconds: 15000),
      headers: baseHeaders,
    );

    final dio = Dio(baseOptions);

    // Attach dynamic Origin header based on stored sub-domain (if not already provided by call)
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        try {
          // If caller already provided Origin in options, keep it
          final hasOrigin = options.headers.containsKey('Origin');
          if (!hasOrigin) {
            final sub = await tokenManager.readSubDomain();
            final origin = origin_resolver.resolveOrigin(sub, defaultSuffix ?? '');
            if (origin != null) {
              options.headers['Origin'] = origin;
            }
          }
          // Inject selected branch id as header X-Branch-Id when available (APIs that require branch id can read it)
          try {
            final branchId = await tokenManager.readSelectedBranchId();
            if (branchId != null && !options.headers.containsKey('X-Branch-Id')) {
              options.headers['X-Branch-Id'] = branchId.toString();
            }
          } catch (_) {}
        } catch (_) {}
        return handler.next(options);
      },
    ));

    dio.interceptors.add(AuthInterceptor(
      tokenManager: tokenManager,
      dio: dio,
      onRefreshToken: onRefresh,
      onLogout: onLogout,
    ));

    return ApiClient._(dio);
  }

  Dio get dio => _dio;

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    return _dio.get<T>(path,
        queryParameters: queryParameters, options: options, cancelToken: cancelToken);
  }

  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    return _dio.post<T>(path,
        data: data, queryParameters: queryParameters, options: options, cancelToken: cancelToken);
  }

  Future<Response<T>> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    return _dio.put<T>(path,
        data: data, queryParameters: queryParameters, options: options, cancelToken: cancelToken);
  }

  Future<Response<T>> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    return _dio.delete<T>(path,
        data: data, queryParameters: queryParameters, options: options, cancelToken: cancelToken);
  }

  Future<Response<T>> patch<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    return _dio.patch<T>(path,
        data: data, queryParameters: queryParameters, options: options, cancelToken: cancelToken);
  }
}
