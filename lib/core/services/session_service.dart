import '../constants/storage_keys.dart';
import 'local_storage_service.dart';

class SessionService {
  final LocalStorageService _storage;
  String? _accessTokenCache;
  int? _userIdCache;
  String? _roleCache;

  /// Called after [clearSession] (logout, delete account, forced 401, etc.).
  static void Function()? onSessionCleared;

  SessionService(this._storage);

  Future<void> saveSession({
    required String accessToken,
    required int userId,
    required String role,
    bool persistSession = true,
  }) async {
    if (persistSession) {
      await _storage.setString(StorageKeys.accessToken, accessToken);
      await _storage.setInt(StorageKeys.userId, userId);
      await _storage.setString(StorageKeys.role, role);
    } else {
      await _storage.remove(StorageKeys.accessToken);
      await _storage.remove(StorageKeys.userId);
      await _storage.remove(StorageKeys.role);
    }
    _accessTokenCache = accessToken;
    _userIdCache = userId;
    _roleCache = role;
  }

  Future<void> setRememberMe(bool value) async {
    await _storage.setBool(StorageKeys.rememberMe, value);
  }

  Future<bool> getRememberMe() async {
    return await _storage.getBool(StorageKeys.rememberMe) ?? false;
  }

  Future<void> setRememberedLogin(String? login) async {
    final value = login?.trim() ?? '';
    if (value.isEmpty) {
      await _storage.remove(StorageKeys.rememberedLogin);
      return;
    }
    await _storage.setString(StorageKeys.rememberedLogin, value);
  }

  Future<String?> getRememberedLogin() async {
    return _storage.getString(StorageKeys.rememberedLogin);
  }

  Future<String?> getAccessToken() async {
    if (_accessTokenCache != null && _accessTokenCache!.isNotEmpty) {
      return _accessTokenCache;
    }
    final token = await _storage.getString(StorageKeys.accessToken);
    _accessTokenCache = token;
    return token;
  }

  Future<int?> getUserId() async {
    if (_userIdCache != null) return _userIdCache;
    final userId = await _storage.getInt(StorageKeys.userId);
    _userIdCache = userId;
    return userId;
  }

  Future<String?> getRole() async {
    if (_roleCache != null && _roleCache!.isNotEmpty) return _roleCache;
    final role = await _storage.getString(StorageKeys.role);
    _roleCache = role;
    return role;
  }

  Future<bool> isAuthorized() async {
    final token = await getAccessToken();
    return token != null && token.isNotEmpty;
  }

  Future<void> clearSession() async {
    await _storage.remove(StorageKeys.accessToken);
    await _storage.remove(StorageKeys.userId);
    await _storage.remove(StorageKeys.role);
    _accessTokenCache = null;
    _userIdCache = null;
    _roleCache = null;
    onSessionCleared?.call();
  }
}