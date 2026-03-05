import 'package:dio/dio.dart';
import 'package:package_info_plus/package_info_plus.dart';

class ReleaseInfo {
  final String tagName;
  final String name;
  final String body;
  final String htmlUrl;

  ReleaseInfo({required this.tagName, required this.name, required this.body, required this.htmlUrl});
}

class VersionCheckService {
  final Dio dio;

  VersionCheckService({Dio? dio}) : dio = dio ?? Dio();

  /// Fetches latest release from GitHub for owner/repo. Returns null on failure.
  Future<ReleaseInfo?> fetchLatestRelease(String owner, String repo) async {
    try {
      final resp = await dio.get('https://api.github.com/repos/$owner/$repo/releases/latest');
      if (resp.statusCode == 200 && resp.data != null) {
        final data = resp.data;
        return ReleaseInfo(
          tagName: data['tag_name'] ?? '',
          name: data['name'] ?? '',
          body: data['body'] ?? '',
          htmlUrl: data['html_url'] ?? '',
        );
      }
    } catch (e) {
      // ignore network errors for now
    }
    return null;
  }

  Future<String> getLocalVersion() async {
    final info = await PackageInfo.fromPlatform();
    return info.version;
  }

  /// Compares semantic versions (major.minor.patch). Returns true if latest > current.
  bool isUpdateAvailable(String current, String latest) {
    try {
      final cv = _parse(current);
      final lv = _parse(latest);
      for (var i = 0; i < 3; i++) {
        if (lv[i] > cv[i]) return true;
        if (lv[i] < cv[i]) return false;
      }
    } catch (e) {
      // On parse error, don't force update
    }
    return false;
  }

  List<int> _parse(String v) {
    final parts = v.split('+').first.split('-').first.split('.');
    final nums = List<int>.filled(3, 0);
    for (var i = 0; i < parts.length && i < 3; i++) {
      nums[i] = int.tryParse(parts[i]) ?? 0;
    }
    return nums;
  }
}
