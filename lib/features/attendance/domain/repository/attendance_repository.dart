import '../entities/attendance_entity.dart';

abstract class AttendanceRepository {
  /// Marks attendance (checkin/checkout) with lat/lng. Returns result with success and optional message.
  Future<AttendanceActionResult> mark({required double latitude, required double longitude});

  /// Fetch attendance records (for user) — may accept optional params later.
  Future<List<AttendanceRecord>> list({int? page, int? pageSize, Map<String, dynamic>? extraQueryParameters});
}
