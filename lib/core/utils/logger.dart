import 'dart:developer' as developer;

class Logger {
  static void d(String message, [Object? error, StackTrace? stackTrace]) {
    developer.log(message, name: 'APP', error: error, stackTrace: stackTrace);
  }

  static void i(String message) => developer.log(message, name: 'APP');
  static void e(String message, [Object? error, StackTrace? st]) =>
      developer.log(message, level: 1000, name: 'APP', error: error, stackTrace: st);
}
