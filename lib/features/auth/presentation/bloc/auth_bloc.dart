import 'dart:async';

import 'package:bloc/bloc.dart';

import '../../../../core/network/token_manager.dart';
import '../../domain/usecases/login_usecase.dart';
import '../../domain/usecases/logout_usecase.dart';
import '../../domain/usecases/refresh_token_usecase.dart';
import '../../domain/repository/auth_repository.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final LoginUseCase loginUseCase;
  final LogoutUseCase logoutUseCase;
  final RefreshTokenUseCase refreshTokenUseCase;
  final TokenManager tokenManager;
  final AuthRepository repository;

  late final StreamSubscription<bool> _authStateSub;

  AuthBloc({
    required this.loginUseCase,
    required this.logoutUseCase,
    required this.refreshTokenUseCase,
    required this.tokenManager,
    required this.repository,
  }) : super(AuthInitial()) {
    on<AppStarted>(_onAppStarted);
    on<LoginRequested>(_onLoginRequested);
    on<LogoutRequested>(_onLogoutRequested);
    on<ForceLogout>(_onForceLogout);

    // Listen to repository-level auth state changes (e.g., force logout)
    try {
      // Expect repository to expose authStateChanges stream (impl provides it)
      final r = repository as dynamic;
      _authStateSub = r.authStateChanges.listen((authenticated) {
        if (!authenticated) add(ForceLogout());
      });
    } catch (_) {
      // ignore if repository doesn't provide stream
      _authStateSub = Stream<bool>.empty().listen((_) {});
    }
    }

  Future<void> _onAppStarted(AppStarted event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    final token = await tokenManager.readAccessToken();
    if (token != null && token.isNotEmpty) {
      emit(AuthAuthenticated());
    } else {
      emit(AuthUnauthenticated());
    }
  }

  Future<void> _onLoginRequested(LoginRequested event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      await loginUseCase.execute(email: event.email, password: event.password, subDomain: event.subDomain, captchaToken: event.captchaToken);
      emit(AuthAuthenticated());
    } catch (e) {
      emit(AuthError(e.toString()));
      emit(AuthUnauthenticated());
    }
  }

  Future<void> _onLogoutRequested(LogoutRequested event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    await logoutUseCase.execute();
    emit(AuthUnauthenticated());
  }

  Future<void> _onForceLogout(ForceLogout event, Emitter<AuthState> emit) async {
    emit(AuthUnauthenticated());
  }

  @override
  Future<void> close() {
    _authStateSub.cancel();
    return super.close();
  }
}
