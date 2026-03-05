import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'core/network/api_client.dart';
import 'core/network/token_manager.dart';
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
import 'main_prod.dart' as prod;

import 'core/ui/theme.dart';
import 'core/widgets/version_gate.dart';

void main() => prod.main();

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Manual wiring for demonstration. In a real app use get_it or similar.
    final secureStorage = const FlutterSecureStorage();
    final tokenManager = TokenManager(secureStorage: secureStorage);

    // Dio instance for auth endpoints (no interceptor) - used by remote datasource for login/refresh
    final authDio = Dio(BaseOptions(baseUrl: 'https://api.example.com'));
    final authRemote = AuthRemoteDataSource(dio: authDio, defaultSubDomain: '');
    final authRepository = AuthRepositoryImpl(remote: authRemote, tokenManager: tokenManager);

    final refreshUseCase = RefreshTokenUseCase(authRepository);

    // Create ApiClient with interceptor that uses the refresh use case and calls repository.forceLogout on logout.
    // We inline ApiClient into the provider below to avoid an unused local variable warning.

    final loginUseCase = LoginUseCase(authRepository);
    final logoutUseCase = LogoutUseCase(authRepository);

    return RepositoryProvider.value(
      value: authRepository,
      child: RepositoryProvider.value(
        value: ApiClient(
          tokenManager: tokenManager,
          onRefresh: () => refreshUseCase.execute(),
          onLogout: () => authRepository.forceLogout(),
        ),
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
          child: VersionGate(
            owner: 'your-org',
            repo: 'your-repo',
            force: false,
            child: MaterialApp(
              title: 'OSOM',
              debugShowCheckedModeBanner: false,
              theme: AppTheme.light(),
              home: const AuthGate(),
              routes: {
                '/dashboard': (context) => const DashboardScreen(),
              },
            ),
          ),
        ),
      ),
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
          return const Scaffold(body: Center(child: Text('Authenticated - Home')));
        }
        if (state is AuthLoading) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        return const LoginPage();
      },
    );
  }
}
