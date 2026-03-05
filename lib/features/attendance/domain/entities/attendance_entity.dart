class AttendanceRecord {
  final int attendanceId;
  final int employeeId;
  final DateTime? date;
  final DateTime? checkInTime;
  final DateTime? checkOutTime;
  final String status; // e.g., present, absent, partial
  final String? checkinLocation;
  final String? checkoutLocation;
  final String? remarks;
  final int? branch;

  AttendanceRecord({
    required this.attendanceId,
    required this.employeeId,
    this.date,
    this.checkInTime,
    this.checkOutTime,
    required this.status,
    this.checkinLocation,
    this.checkoutLocation,
    this.remarks,
    this.branch,
  });
}

class AttendanceActionResult {
  final bool success;
  final String? message;
  final AttendanceRecord? attendance;

  AttendanceActionResult({required this.success, this.message, this.attendance});
}
