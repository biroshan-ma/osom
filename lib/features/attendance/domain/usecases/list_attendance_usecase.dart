import '../repository/attendance_repository.dart';

class ListAttendanceUseCase {
  final AttendanceRepository repository;
  ListAttendanceUseCase(this.repository);

  Future execute({int? page, int? pageSize, Map<String, dynamic>? extraQueryParameters}) async {
    return repository.list(page: page, pageSize: pageSize, extraQueryParameters: extraQueryParameters);
  }
}
