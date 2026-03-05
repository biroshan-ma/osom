import 'package:dio/dio.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/api_client.dart';

class AttendanceRemoteDataSource {
  final ApiClient apiClient;
  AttendanceRemoteDataSource({required this.apiClient});

  Future<Response> mark({required double latitude, required double longitude}) async {
    final resp = await apiClient.post(ApiConstants.attendanceMark, data: {'latitude': latitude, 'longitude': longitude});
    return resp;
  }

  Future<Response> list({int? page, int? pageSize, Map<String, dynamic>? extraQueryParameters}) async {
    final qp = <String, dynamic>{};
    if (page != null) qp['page'] = page;
    if (pageSize != null) qp['pageSize'] = pageSize;
    if (extraQueryParameters != null) qp.addAll(extraQueryParameters);
    final resp = await apiClient.get(ApiConstants.attendanceList, queryParameters: qp);
    return resp;
  }
}
