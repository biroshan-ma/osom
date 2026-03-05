class ApiConstants {
  // Set your base API URL in your app's configuration/environment.
  // Do NOT hardcode production URLs here; prefer runtime config.
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://192.168.114.149/8000',
  );

  // Endpoints (build paths using baseUrl + these)
  static const String login = '/api/auth/login';
  static const String logout = '/api/auth/logout';
  static const String userProfile = '/api/auth/me';
  static const String refreshToken = '/auth/refresh';
  // Branch list (consultancy)
  static const String branchList = '/api/1/consultancy/branch';
  // Attendance endpoints
  // POST to mark checkin/checkout
  static const String attendanceMark = '/api/1/attendance/mark';
  // Attendance list endpoint (assumption): returns attendance records. If your API uses a different path,
  // update this constant accordingly.
  static const String attendanceList = '/api/1/attendance';
}
