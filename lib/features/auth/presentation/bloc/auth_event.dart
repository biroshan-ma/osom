import 'package:equatable/equatable.dart';

abstract class AuthEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class AppStarted extends AuthEvent {}

class LoginRequested extends AuthEvent {
  final String email;
  final String password;
  final String subDomain;
  final String captchaToken; // made optional

  LoginRequested({
    required this.email,
    required this.password,
    required this.subDomain,
    required this.captchaToken,
  });

  @override
  List<Object?> get props => [email, password, subDomain, captchaToken];
}

class LogoutRequested extends AuthEvent {}

class ForceLogout extends AuthEvent {}
