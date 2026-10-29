import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StoredSession {
  final String token;
  final String user;

  const StoredSession({required this.token, required this.user});
}

class SessionStore {
  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'auth_user';

  static const FlutterSecureStorage _secure = FlutterSecureStorage();

  static Future<void> save({required String token, required String user}) async {
    await _secure.write(key: _tokenKey, value: token);
    await _secure.write(key: _userKey, value: user);
  }

  static Future<StoredSession?> read() async {
    final token = await _secure.read(key: _tokenKey);
    final user = await _secure.read(key: _userKey);
    if (token != null && user != null) return StoredSession(token: token, user: user);
    return _migrateFromPlainStorage();
  }

  static Future<void> clear() async {
    await _secure.delete(key: _tokenKey);
    await _secure.delete(key: _userKey);
    await _removePlain(await SharedPreferences.getInstance());
  }

  static Future<StoredSession?> _migrateFromPlainStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    final user = prefs.getString(_userKey);
    if (token == null || user == null) return null;

    await save(token: token, user: user);
    await _removePlain(prefs);
    return StoredSession(token: token, user: user);
  }

  static Future<void> _removePlain(SharedPreferences prefs) async {
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
  }
}
