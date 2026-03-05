import 'package:equatable/equatable.dart';
import '../../domain/entities/attendance_entity.dart';

abstract class AttendanceState extends Equatable {
  @override
  List<Object?> get props => [];
}

class AttendanceInitial extends AttendanceState {}
class AttendanceLoading extends AttendanceState {}
class AttendanceLoaded extends AttendanceState {
  final List<AttendanceRecord> records;
  // current reference 'now' used for calculating durations without relying on UI setState
  final DateTime now;

  AttendanceLoaded(this.records, {DateTime? now}) : now = now ?? DateTime.now();

  @override
  List<Object?> get props => [records, now];
}
class AttendanceError extends AttendanceState {
  final String message;
  AttendanceError(this.message);
  @override
  List<Object?> get props => [message];
}
class AttendanceActionInProgress extends AttendanceState {}
class AttendanceActionSuccess extends AttendanceState {
  final String? message;
  AttendanceActionSuccess([this.message]);
  @override
  List<Object?> get props => [message];
}
class AttendanceActionFailure extends AttendanceState {
  final String message;
  AttendanceActionFailure(this.message);
  @override
  List<Object?> get props => [message];
}
