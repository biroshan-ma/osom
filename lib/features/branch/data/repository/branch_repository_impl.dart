import 'package:dio/dio.dart';

import '../../domain/entities/branch_entity.dart';
import '../../domain/repository/branch_repository.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/origin_resolver.dart' show resolveOrigin;
import '../../../../core/network/token_manager.dart';

class BranchRepositoryImpl implements BranchRepository {
  final ApiClient apiClient;
  final TokenManager tokenManager;
  final String defaultSuffix;

  BranchRepositoryImpl({required this.apiClient, required this.tokenManager, required this.defaultSuffix});

  @override
  Future<List<BranchEntity>> listBranches() async {
    final subDomain = await tokenManager.readSubDomain();
    final origin = resolveOrigin(subDomain, defaultSuffix);
    final options = origin != null ? Options(headers: {'Origin': origin}) : null;

    final resp = await apiClient.get(ApiConstants.branchList, options: options);
    final status = resp.statusCode ?? 0;
    if (status >= 200 && status < 300) {
      final data = resp.data;
      // Expecting shape: { "pageCount":..., "data": [ {id, consultancy_name, consultancy_desc, consultancy_logo}, ... ], "count": "9" }
      if (data is Map<String, dynamic>) {
        final listNode = data['data'];
        if (listNode is List) {
          final out = <BranchEntity>[];
          for (final item in listNode) {
            if (item is Map<String, dynamic>) {
              final id = item['id'] is int ? item['id'] as int : int.tryParse(item['id']?.toString() ?? '') ?? 0;
              final name = (item['consultancy_name'] ?? item['name'] ?? '') as String;
              final desc = (item['consultancy_desc'] ?? item['description'] ?? '') as String;
              final logo = item['consultancy_logo']?.toString();
              out.add(BranchEntity(id: id, consultancyName: name, consultancyDesc: desc, consultancyLogo: logo));
            }
          }
          return out;
        }
      }

      // fallback: if response itself is list
      if (resp.data is List) {
        final out = <BranchEntity>[];
        for (final item in resp.data as List) {
          if (item is Map<String, dynamic>) {
            final id = item['id'] is int ? item['id'] as int : int.tryParse(item['id']?.toString() ?? '') ?? 0;
            final name = (item['consultancy_name'] ?? item['name'] ?? '') as String;
            final desc = (item['consultancy_desc'] ?? item['description'] ?? '') as String;
            final logo = item['consultancy_logo']?.toString();
            out.add(BranchEntity(id: id, consultancyName: name, consultancyDesc: desc, consultancyLogo: logo));
          }
        }
        return out;
      }

      return <BranchEntity>[];
    }

    if (status == 401) {
      throw DioException(requestOptions: resp.requestOptions, response: resp);
    }

    throw Exception('Failed to load branches: ${resp.statusMessage}');
  }
}

