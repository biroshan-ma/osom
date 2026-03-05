import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TokenManager {
  final FlutterSecureStorage _secureStorage;
  final SharedPreferences? _prefs;

  static const _keyAccess = 'access_token';
  static const _keyRefresh = 'refresh_token';
  static const _keySubDomain = 'sub_domain';
  static const _keySelectedBranch = 'selected_branch_id';

  /// Provide [secureStorage] and optionally [sharedPreferences]. If [sharedPreferences]
  /// is not provided, TokenManager will fallback to secure storage for sub-domain to
  /// remain backwards compatible (but callers should pass SharedPreferences).
  TokenManager({FlutterSecureStorage? secureStorage, SharedPreferences? sharedPreferences})
      : _secureStorage = secureStorage ?? const FlutterSecureStorage(),
        _prefs = sharedPreferences;

  Future<void> saveAccessToken(String token) async {
    await _secureStorage.write(key: _keyAccess, value: token);
  }

  Future<String?> readAccessToken() async {
    return await _secureStorage.read(key: _keyAccess);
  }

  Future<void> deleteAccessToken() async {
    await _secureStorage.delete(key: _keyAccess);
  }

  Future<void> saveRefreshToken(String token) async {
    await _secureStorage.write(key: _keyRefresh, value: token);
  }

  Future<String?> readRefreshToken() async {
    return await _secureStorage.read(key: _keyRefresh);
  }

  Future<void> deleteRefreshToken() async {
    await _secureStorage.delete(key: _keyRefresh);
  }

  Future<bool> hasRefreshToken() async {
    final t = await readRefreshToken();
    return t != null && t.isNotEmpty;
  }

  /// Save the tenant sub-domain used for Origin headers. Example: 'acme' or 'acme.localhost:5173'
  /// This will use SharedPreferences when available (recommended). If SharedPreferences was not
  /// provided during construction, falls back to secure storage.
  Future<void> saveSubDomain(String subDomain) async {
    if (_prefs != null) {
      await _prefs.setString(_keySubDomain, subDomain);
      return;
    }
    // fallback
    await _secureStorage.write(key: _keySubDomain, value: subDomain);
  }

  /// Read the stored tenant sub-domain, or null if not present.
  Future<String?> readSubDomain() async {
    if (_prefs != null) {
      return _prefs.getString(_keySubDomain);
    }
    return await _secureStorage.read(key: _keySubDomain);
  }

  /// Delete stored tenant sub-domain.
  Future<void> deleteSubDomain() async {
    if (_prefs != null) {
      await _prefs.remove(_keySubDomain);
      return;
    }
    await _secureStorage.delete(key: _keySubDomain);
  }

  /// Save the selected branch id. Prefer SharedPreferences when available.
  Future<void> saveSelectedBranchId(int branchId) async {
    if (_prefs != null) {
      await _prefs.setInt(_keySelectedBranch, branchId);
      return;
    }
    await _secureStorage.write(key: _keySelectedBranch, value: branchId.toString());
  }

  /// Read the selected branch id, or null if not present.
  Future<int?> readSelectedBranchId() async {
    if (_prefs != null) {
      return _prefs.getInt(_keySelectedBranch);
    }
    final v = await _secureStorage.read(key: _keySelectedBranch);
    if (v == null) return null;
    return int.tryParse(v);
  }

  /// Delete saved selected branch id.
  Future<void> deleteSelectedBranchId() async {
    if (_prefs != null) {
      await _prefs.remove(_keySelectedBranch);
      return;
    }
    await _secureStorage.delete(key: _keySelectedBranch);
  }

  Future<void> clearAll() async {
    await _secureStorage.delete(key: _keyAccess);
    await _secureStorage.delete(key: _keyRefresh);
    // also remove sub-domain from both stores (prefs if present)
    if (_prefs != null) {
      await _prefs.remove(_keySubDomain);
      await _prefs.remove(_keySelectedBranch);
    } else {
      await _secureStorage.delete(key: _keySubDomain);
      await _secureStorage.delete(key: _keySelectedBranch);
    }
  }
}
