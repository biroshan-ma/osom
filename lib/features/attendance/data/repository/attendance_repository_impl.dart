import '../../domain/entities/attendance_entity.dart';
import '../../domain/repository/attendance_repository.dart';
import '../datasource/attendance_remote_datasource.dart';

class AttendanceRepositoryImpl implements AttendanceRepository {
  final AttendanceRemoteDataSource remote;

  AttendanceRepositoryImpl({required this.remote});

  DateTime? _parseDateTimeParts(String? datePart, String? timePart) {
    if (datePart == null && timePart == null) return null;
    // If timePart already contains a full ISO timestamp, try parsing directly
    if (timePart != null) {
      final t = DateTime.tryParse(timePart);
      if (t != null) return t;
    }
    // If datePart contains full datetime, try that
    if (datePart != null) {
      final d = DateTime.tryParse(datePart);
      if (d != null && (timePart == null || timePart.trim().isEmpty)) return null;
    }
    // If we have a date and a time string like '12:59:28', combine them into an ISO string
    if (datePart != null && timePart != null) {
      try {
        final combined = '${datePart.trim()}T${timePart.trim()}';
        final parsed = DateTime.tryParse(combined);
        if (parsed != null) return parsed;
        // As a fallback, try appending seconds if missing
        final parts = timePart.split(':');
        if (parts.length == 2) {
          final combined2 = '${datePart.trim()}T${timePart.trim()}:00';
          return DateTime.tryParse(combined2);
        }
      } catch (_) {}
    }
    return null;
  }

  AttendanceRecord _parseAttendanceMap(Map<String, dynamic> item) {
    final attendanceId = item['attendance_id'] is int ? item['attendance_id'] as int : int.tryParse(item['attendance_id']?.toString() ?? '') ?? 0;
    final employeeId = item['employee_id'] is int ? item['employee_id'] as int : int.tryParse(item['employee_id']?.toString() ?? '') ?? 0;

    final rawDate = item['date']?.toString();
    final rawCheckIn = item['check_in_time']?.toString();
    final rawCheckOut = item['check_out_time']?.toString();

    final date = rawDate != null ? DateTime.tryParse(rawDate) : null;
    // Try to parse check-in/check-out robustly: handle full datetime or separate date + time strings
    final checkIn = _parseDateTimeParts(rawDate, rawCheckIn);
    final checkOut = _parseDateTimeParts(rawDate, rawCheckOut);

    final statusText = (item['status'] ?? '')?.toString() ?? '';
    final checkinLocation = item['checkin_location']?.toString();
    final checkoutLocation = item['checkout_location']?.toString();
    final remarks = item['remarks']?.toString();
    final branch = item['branch'] is int ? item['branch'] as int : int.tryParse(item['branch']?.toString() ?? '');

    return AttendanceRecord(
      attendanceId: attendanceId,
      employeeId: employeeId,
      date: date,
      checkInTime: checkIn,
      checkOutTime: checkOut,
      status: statusText,
      checkinLocation: checkinLocation,
      checkoutLocation: checkoutLocation,
      remarks: remarks,
      branch: branch,
    );
  }

  @override
  Future<List<AttendanceRecord>> list({int? page, int? pageSize, Map<String, dynamic>? extraQueryParameters}) async {
    final resp = await remote.list(page: page, pageSize: pageSize, extraQueryParameters: extraQueryParameters);
    final status = resp.statusCode ?? 0;
    if (status >= 200 && status < 300) {
      final data = resp.data;
      final out = <AttendanceRecord>[];

      if (data is Map<String, dynamic>) {
        // According to provided sample, GET /attendance returns: { success: true, attendance: {...} }
        if (data['attendance'] is Map<String, dynamic>) {
          out.add(_parseAttendanceMap(Map<String, dynamic>.from(data['attendance'])));
          return out;
        }
        // fallback: if data['data'] is list
        if (data['data'] is List) {
          for (final item in data['data']) {
            if (item is Map<String, dynamic>) {
              out.add(_parseAttendanceMap(Map<String, dynamic>.from(item)));
            }
          }
          return out;
        }
      }

      if (data is List) {
        for (final item in data) {
          if (item is Map<String, dynamic>) {
            out.add(_parseAttendanceMap(Map<String, dynamic>.from(item)));
          }
        }
        return out;
      }

      return out;
    }

    throw Exception('Failed to load attendance: ${resp.statusMessage}');
  }

  @override
  Future<AttendanceActionResult> mark({required double latitude, required double longitude}) async {
    final resp = await remote.mark(latitude: latitude, longitude: longitude);
    final status = resp.statusCode ?? 0;
    if (status >= 200 && status < 300) {
      if (resp.data is Map<String, dynamic>) {
        final data = Map<String, dynamic>.from(resp.data as Map);
        final success = data['success'] == true;
        final message = data['message']?.toString();
        AttendanceRecord? attendance;
        if (data['attendance'] is Map<String, dynamic>) {
          attendance = _parseAttendanceMap(Map<String, dynamic>.from(data['attendance'] as Map));
        }
        return AttendanceActionResult(success: success, message: message, attendance: attendance);
      }
      return AttendanceActionResult(success: true);
    }

    final msg = resp.data is Map<String, dynamic> ? (resp.data['message']?.toString() ?? resp.statusMessage) : resp.statusMessage;
    return AttendanceActionResult(success: false, message: msg?.toString());
  }
}
