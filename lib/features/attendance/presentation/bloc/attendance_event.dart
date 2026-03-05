import 'package:equatable/equatable.dart';

abstract class AttendanceEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class LoadAttendance extends AttendanceEvent {
  final bool forceRefresh;
  LoadAttendance({this.forceRefresh = false});

  @override
  List<Object?> get props => [forceRefresh];
}

class MarkAttendance extends AttendanceEvent {
  final double latitude;
  final double longitude;

  MarkAttendance({required this.latitude, required this.longitude});

  @override
  List<Object?> get props => [latitude, longitude];
}

/// Internal event used by the bloc to tick the current time while an active session is running.
class Tick extends AttendanceEvent {}
