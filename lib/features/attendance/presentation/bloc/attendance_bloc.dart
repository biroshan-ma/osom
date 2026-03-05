import 'package:bloc/bloc.dart';
import 'package:dio/dio.dart';
import 'dart:async';

import '../../domain/usecases/list_attendance_usecase.dart';
import '../../domain/usecases/mark_attendance_usecase.dart';
import 'attendance_event.dart';
import 'attendance_state.dart';

class AttendanceBloc extends Bloc<AttendanceEvent, AttendanceState> {
  final ListAttendanceUseCase listUseCase;
  final MarkAttendanceUseCase markUseCase;
  Timer? _ticker;

  AttendanceBloc({required this.listUseCase, required this.markUseCase}) : super(AttendanceInitial()) {
    on<LoadAttendance>(_onLoad);
    on<MarkAttendance>(_onMark);
    on<Tick>(_onTick);
  }

  Future<void> _onLoad(LoadAttendance event, Emitter<AttendanceState> emit) async {
    emit(AttendanceLoading());
    try {
      final extra = event.forceRefresh ? {'ts': DateTime.now().millisecondsSinceEpoch} : null;
      final res = await listUseCase.execute(extraQueryParameters: extra);
      final loaded = AttendanceLoaded(res);
      emit(loaded);
      // start/stop internal ticker depending on active session
      _scheduleTickerIfNeeded(loaded, emit);
    } on DioException catch (e) {
      final msg = e.response?.data is Map<String, dynamic> ? (e.response?.data['message'] ?? e.message) : e.message;
      emit(AttendanceError(msg?.toString() ?? 'Failed to load attendance'));
    } catch (e) {
      emit(AttendanceError(e.toString()));
    }
  }

  void _scheduleTickerIfNeeded(AttendanceLoaded state, Emitter<AttendanceState> emit) {
    final todayRecord = state.records.isNotEmpty ? state.records.first : null;
    final bool isActiveSession = todayRecord != null && todayRecord.checkInTime != null && todayRecord.checkOutTime == null;
    // if active, ensure ticker is running
    if (isActiveSession) {
      _ticker ??= Timer.periodic(const Duration(seconds: 1), (_) {
          add(Tick());
        });
    } else {
      // no active session -> cancel ticker
      _ticker?.cancel();
      _ticker = null;
    }
  }

  Future<void> _onTick(Tick event, Emitter<AttendanceState> emit) async {
    // if currently loaded, re-emit AttendanceLoaded with updated now
    final current = state;
    if (current is AttendanceLoaded) {
      emit(AttendanceLoaded(current.records, now: DateTime.now()));
    }
  }

  Future<void> _onMark(MarkAttendance event, Emitter<AttendanceState> emit) async {
    emit(AttendanceActionInProgress());
    try {
      final res = await markUseCase.execute(latitude: event.latitude, longitude: event.longitude);
      if (res.success == true) {
        emit(AttendanceActionSuccess(res.message));
        // reload list (UI will update from the list API only)
        add(LoadAttendance(forceRefresh: true));
        return;
      }
      // Special-case: if the backend reports the user already checked out for today,
      // refresh the list so the UI can display the check-in/check-out details.
      final lowerMsg = (res.message ?? '').toString().toLowerCase();
      if (lowerMsg.contains('already checkout') || lowerMsg.contains('already checked out') || lowerMsg.contains('already checkout for today')) {
        emit(AttendanceActionFailure(res.message ?? 'Already checked out'));
        add(LoadAttendance(forceRefresh: true));
        return;
      }

      emit(AttendanceActionFailure(res.message ?? 'Failed to mark attendance'));
    } on DioException catch (e) {
      final msg = e.response?.data is Map<String, dynamic>
          ? (e.response?.data['message'] ?? e.message)
          : e.message;
      final text = msg?.toString() ?? '';
      // If server responded with 409 / Already checkout, refresh the list so UI shows latest attendance.
      if (e.response?.statusCode == 409 && text.toLowerCase().contains('already checkout')) {
        emit(AttendanceActionFailure(text));
        add(LoadAttendance(forceRefresh: true));
        return;
      }
      emit(AttendanceActionFailure(text.isNotEmpty ? text : 'Failed to mark attendance'));
    } catch (e) {
      emit(AttendanceActionFailure(e.toString()));
    }
  }

  @override
  Future<void> close() {
    _ticker?.cancel();
    return super.close();
  }
}
