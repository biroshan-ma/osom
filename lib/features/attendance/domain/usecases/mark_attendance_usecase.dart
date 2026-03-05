import '../repository/attendance_repository.dart';

class MarkAttendanceUseCase {
  final AttendanceRepository repository;
  MarkAttendanceUseCase(this.repository);

  Future execute({required double latitude, required double longitude}) async {
    return repository.mark(latitude: latitude, longitude: longitude);
  }
}

