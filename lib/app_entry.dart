import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/env/app_config.dart';
import 'core/network/api_client.dart';
import 'core/network/token_manager.dart';
import 'core/network/dio_interceptor.dart';
import 'features/auth/data/datasource/auth_remote_datasource.dart';
import 'features/auth/data/repository/auth_repository_impl.dart';
import 'features/auth/domain/usecases/login_usecase.dart';
import 'features/auth/domain/usecases/logout_usecase.dart';
import 'features/auth/domain/usecases/refresh_token_usecase.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/auth/presentation/bloc/auth_event.dart';
import 'features/auth/presentation/bloc/auth_state.dart';
import 'features/auth/presentation/pages/login_page.dart';
import 'features/dashboard/presentation/pages/dashboard_screen.dart';
import 'features/core/presentation/pages/splash_screen.dart';
import 'features/user/data/repository/user_repository_impl.dart';
import 'features/user/domain/repository/user_repository.dart';
import 'features/branch/data/repository/branch_repository_impl.dart';
import 'features/branch/domain/repository/branch_repository.dart';
import 'features/attendance/data/datasource/attendance_remote_datasource.dart';
import 'features/attendance/data/repository/attendance_repository_impl.dart';
import 'features/attendance/domain/repository/attendance_repository.dart';
import 'features/attendance/presentation/pages/attendance_page.dart';
import 'core/ui/theme.dart';

class AppEntry extends StatelessWidget {
  final AppConfig config;
  const AppEntry({super.key, required this.config});

  Future<String> _getDeviceId() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        return androidInfo.id;
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        return iosInfo.identifierForVendor ?? 'device-unknown';
      }
    } catch (_) {}
    return 'device-unknown';
  }

  /// Performs initialization (deviceId + prefs) and, if an access token exists,
  /// attempts to preload the user's display name by calling `auth/me`.
  Future<Map<String, Object?>> _initializeAndPrefetch() async {
    final deviceId = await _getDeviceId();
    final prefs = await SharedPreferences.getInstance();

    final secureStorage = const FlutterSecureStorage();
    final tokenManager = TokenManager(secureStorage: secureStorage, sharedPreferences: prefs);

    // Prepare Dio and ApiClient to call user/me
    final authDio = Dio(BaseOptions(baseUrl: config.apiBaseUrl, headers: {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'X-Client-Type': 'mobile',
      'X-Device-Id': deviceId,
    }));

    final authRemote = AuthRemoteDataSource(dio: authDio, defaultSubDomain: config.defaultSubDomain);
    final authRepository = AuthRepositoryImpl(remote: authRemote, tokenManager: tokenManager, defaultSubDomain: config.defaultSubDomain);
    final refreshUseCase = RefreshTokenUseCase(authRepository);

    authDio.interceptors.add(AuthInterceptor(
      tokenManager: tokenManager,
      dio: authDio,
      onRefreshToken: () => refreshUseCase.execute(),
      onLogout: () => authRepository.forceLogout(),
    ));

    // Build an ApiClient for prefetch calls
    final apiClient = ApiClient(
      tokenManager: tokenManager,
      onRefresh: () => refreshUseCase.execute(),
      onLogout: () => authRepository.forceLogout(),
      baseUrl: config.apiBaseUrl,
      deviceId: deviceId,
      defaultSuffix: config.defaultSubDomain,
    );

    String? preloadedName;
    try {
      final access = await tokenManager.readAccessToken();
      if (access != null && access.isNotEmpty) {
        final userRepo = UserRepositoryImpl(apiClient: apiClient, tokenManager: tokenManager, defaultSuffix: config.defaultSubDomain);
        try {
          final user = await userRepo.me();
          preloadedName = user.fullName;
        } catch (_) {
          // ignore prefetch errors; we'll fall back to normal load in ProfilePage
        }
      }
    } catch (_) {}

    return {
      'deviceId': deviceId,
      'prefs': prefs,
      'preloadedName': preloadedName,
    };
  }

  @override
  Widget build(BuildContext context) {
    // Use our combined initializer which may prefetch user name when a token exists
    final initialization = _initializeAndPrefetch();

    return MaterialApp(
      title: 'OSOM Enterprise',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: FutureBuilder<Map<String, Object?>>(
        future: initialization,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const SplashScreen();
          }

          if (snapshot.hasError) {
            // Log and show splash; retry logic could be added here
            // ignore: avoid_print
            print('Initialization error: ${snapshot.error}');
            return const SplashScreen();
          }

          final deviceId = (snapshot.data?['deviceId'] as String?) ?? 'device-unknown';
          final prefs = (snapshot.data?['prefs'] as SharedPreferences?);
          final preloadedName = (snapshot.data?['preloadedName'] as String?);

          final secureStorage = const FlutterSecureStorage();
          final tokenManager = TokenManager(secureStorage: secureStorage, sharedPreferences: prefs);

          final authDio = Dio(BaseOptions(baseUrl: config.apiBaseUrl, headers: {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
            'X-Client-Type': 'mobile',
            'X-Device-Id': deviceId,
          }));

          final authRemote = AuthRemoteDataSource(dio: authDio, defaultSubDomain: config.defaultSubDomain);
          final authRepository = AuthRepositoryImpl(remote: authRemote, tokenManager: tokenManager, defaultSubDomain: config.defaultSubDomain);

          final refreshUseCase = RefreshTokenUseCase(authRepository);
          final loginUseCase = LoginUseCase(authRepository);
          final logoutUseCase = LogoutUseCase(authRepository);

          authDio.interceptors.add(AuthInterceptor(
            tokenManager: tokenManager,
            dio: authDio,
            onRefreshToken: () => refreshUseCase.execute(),
            onLogout: () => authRepository.forceLogout(),
          ));

          return MultiRepositoryProvider(
            providers: [
              RepositoryProvider.value(value: authRepository),
              RepositoryProvider<TokenManager>(create: (context) => tokenManager),
              RepositoryProvider<ApiClient>(
                create: (context) => ApiClient(
                  tokenManager: tokenManager,
                  onRefresh: () => refreshUseCase.execute(),
                  onLogout: () => authRepository.forceLogout(),
                  baseUrl: config.apiBaseUrl,
                  deviceId: deviceId,
                  defaultSuffix: config.defaultSubDomain,
                ),
              ),
              // Provide preloaded user display name (may be null). ProfilePage will use this if available to avoid the spinner.
              RepositoryProvider<String?>(create: (context) => preloadedName),
              RepositoryProvider<UserRepository>(
                create: (context) => UserRepositoryImpl(
                  apiClient: RepositoryProvider.of<ApiClient>(context),
                  tokenManager: RepositoryProvider.of<TokenManager>(context),
                  defaultSuffix: config.defaultSubDomain,
                ),
              ),
              RepositoryProvider<BranchRepository>(
                create: (context) => BranchRepositoryImpl(
                  apiClient: RepositoryProvider.of<ApiClient>(context),
                  tokenManager: RepositoryProvider.of<TokenManager>(context),
                  defaultSuffix: config.defaultSubDomain,
                ),
              ),
              RepositoryProvider<AttendanceRepository>(
                create: (context) => AttendanceRepositoryImpl(
                  remote: AttendanceRemoteDataSource(apiClient: RepositoryProvider.of<ApiClient>(context)),
                ),
              ),
              RepositoryProvider<AppConfig>(create: (context) => config),
            ],
            child: MultiBlocProvider(
              providers: [
                BlocProvider<AuthBloc>(
                  create: (context) => AuthBloc(
                    loginUseCase: loginUseCase,
                    logoutUseCase: logoutUseCase,
                    refreshTokenUseCase: refreshUseCase,
                    tokenManager: tokenManager,
                    repository: authRepository,
                  )..add(AppStarted()),
                )
              ],
              child: const AuthGate(),
            ),
          );
        },
      ),
      routes: {
        '/dashboard': (context) => const DashboardScreen(),
        '/attendance': (context) => const AttendancePage(),
      },
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, dynamic>(
      builder: (context, state) {
        if (state is AuthAuthenticated) {
          return const DashboardScreen();
        }
        // Show splash during initial/loading states to avoid UI flicker while auth checks run
        if (state is AuthInitial || state is AuthLoading) {
          return const SplashScreen();
        }
        return const LoginPage();
      },
    );
  }
}
