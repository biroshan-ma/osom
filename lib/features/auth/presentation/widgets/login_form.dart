import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:osom/core/env/app_config.dart';

import '../../../../core/ui/widgets/input_field.dart';
import '../../../../core/ui/widgets/primary_button.dart';
import '../../../../core/ui/colors.dart';

import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';

import '../../../../core/services/turnstile_service.dart';

// Additional imports for fallback bloc construction
import '../../domain/usecases/login_usecase.dart';
import '../../domain/usecases/logout_usecase.dart';
import '../../domain/usecases/refresh_token_usecase.dart';
import '../../domain/repository/auth_repository.dart';
import '../../../../core/network/token_manager.dart';

class LoginForm extends StatefulWidget {
  const LoginForm({super.key});

  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  final _formKey = GlobalKey<FormState>();
  final _subDomainController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  final _subDomainFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();

  bool _obscure = true;

  @override
  void dispose() {
    _subDomainController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _subDomainFocus.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  String? _requiredValidator(String? v) {
    if (v == null || v.trim().isEmpty) return 'This field is required';
    return null;
  }

  String? _emailValidator(String? v) {
    if (v == null || v.trim().isEmpty) return 'Email is required';
    final email = v.trim();
    final regex = RegExp(r"^[^\s@]+@[^\s@]+\.[^\s@]+$");
    if (!regex.hasMatch(email)) return 'Enter a valid email';
    return null;
  }

  String? _passwordValidator(String? v) {
    if (v == null || v.isEmpty) return 'Password is required';
    if (v.length < 6) return 'Password must be at least 6 characters';
    return null;
  }

  Future<void> _submit() async {
    final form = _formKey.currentState!;
    if (!form.validate()) return;

    // Retrieve Turnstile token before dispatching login
    String? token;
    try {
      token = await TurnstileService.token;
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Captcha error')));
      token = null;
    }

    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not obtain captcha token')));
    }

    final event = LoginRequested(
      email: _emailController.text.trim(),
      password: _passwordController.text.trim(),
      subDomain: _subDomainController.text.trim(),
      captchaToken: token ?? '',
    );

    // Try to dispatch to nearest AuthBloc; if it's closed, fallback to creating a short-lived bloc
    try {
      final bloc = BlocProvider.of<AuthBloc>(context, listen: false);
      // Avoid calling add if the bloc has already been closed
      if (bloc.isClosed) throw StateError('AuthBloc is closed');
      bloc.add(event);
    } catch (e) {
      debugPrint('Nearest AuthBloc appears closed or unavailable: $e — using temporary bloc fallback');
      try {
        final authRepo = RepositoryProvider.of<AuthRepository>(context);
        final tokenManager = RepositoryProvider.of<TokenManager>(context);
        final tempBloc = AuthBloc(
          loginUseCase: LoginUseCase(authRepo),
          logoutUseCase: LogoutUseCase(authRepo),
          refreshTokenUseCase: RefreshTokenUseCase(authRepo),
          tokenManager: tokenManager,
          repository: authRepo,
        );

        // Listen to temp bloc to handle navigation and feedback, then close it
        late final StreamSubscription sub;
        sub = tempBloc.stream.listen((state) {
          if (state is AuthAuthenticated) {
            Navigator.pushReplacementNamed(context, '/dashboard');
            sub.cancel();
            tempBloc.close();
          } else if (state is AuthError || state is AuthUnauthenticated) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state is AuthError ? state.message : 'Login failed')));
            sub.cancel();
            tempBloc.close();
          }
        });

        tempBloc.add(event);
      } catch (e2) {
        debugPrint('Fallback login failed: $e2');
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Login failed (internal error)')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Try to obtain nearest AuthBloc; fall back to null if not provided.
    AuthBloc? maybeBloc;
    try {
      maybeBloc = BlocProvider.of<AuthBloc>(context);
    } catch (_) {
      maybeBloc = null;
    }

    if (maybeBloc != null) {
      return BlocConsumer<AuthBloc, dynamic>(
        listener: (context, state) {
          if (state is AuthError) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.message)));
          }
          if (state is AuthAuthenticated) {
            Navigator.pushReplacementNamed(context, '/dashboard');
          }
        },
        builder: (context, state) {
          final isLoading = state is AuthLoading;
          return _buildForm(context, isLoading);
        },
      );
    }

    // No AuthBloc in the tree (e.g. being used in isolation) - render the form and let _submit handle fallback.
    return _buildForm(context, false);
  }

  // Extracted form builder to reuse for both cases
  Widget _buildForm(BuildContext context, bool isLoading) {
    return Card(
      elevation: 0,
      color: Colors.transparent,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: InputField(
                    label: 'Sub-domain',
                    hint: 'your company',
                    controller: _subDomainController,
                    validator: _requiredValidator,
                    textInputAction: TextInputAction.next,
                    focusNode: _subDomainFocus,
                  ),
                ),
                const SizedBox(width: 16),
                Text(AppConfig.production().defaultSubDomain, style: const TextStyle(color: AppColors.textSecondary))
              ],
            ),
            const SizedBox(height: 16),
            InputField(
              label: 'Email',
              hint: 'Enter your email',
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              validator: _emailValidator,
              textInputAction: TextInputAction.next,
              focusNode: _emailFocus,
            ),
            const SizedBox(height: 16),
            InputField(
              label: 'Password',
              hint: 'Enter your password',
              controller: _passwordController,
              obscureText: _obscure,
              validator: _passwordValidator,
              focusNode: _passwordFocus,
              textInputAction: TextInputAction.done,
              suffix: IconButton(
                onPressed: () => setState(() => _obscure = !_obscure),
                icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off, color: AppColors.textSecondary),
              ),
            ),
            const SizedBox(height: 8),
            // Align(
            //   alignment: Alignment.centerRight,
            //   child: TextButton(
            //     onPressed: () {},
            //     child: const Text('Forgot Password?'),
            //   ),
            // ),
            const SizedBox(height: 16),
            PrimaryButton(
              text: 'Sign In',
              loading: isLoading,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}
