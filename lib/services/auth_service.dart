import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_client.dart';

// User authentication (Juan Felipe Ochoa)
// - register / login against the FastAPI backend (/auth/register, /auth/login)
// - keeps the session (JWT) on the phone so the user does not log in every time
// - restoreSession() validates the saved token with /auth/me when the app starts

// The logged-in user, as answered by the backend
class AuthUser {
  final int id;
  final String name;
  final String email;

  const AuthUser({required this.id, required this.name, required this.email});

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
        id: (json['id'] as num).toInt(),
        name: json['name'] as String,
        email: json['email'] as String,
      );

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'email': email};
}

// Error with a message ready to be shown to the user in the login screen
class AuthException implements Exception {
  final String message;
  AuthException(this.message);

  @override
  String toString() => message;
}

class AuthService {
  static final ApiClient _api = ApiClient(); // Singleton shared with the other services
  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'auth_user';

  // Who is logged in right now (null = nobody). Screens can listen to it, like userProfile
  static final ValueNotifier<AuthUser?> currentUser = ValueNotifier(null);

  static Future<AuthUser> register({required String name, required String email, required String password}) {
    return _authenticate('/auth/register', {'name': name, 'email': email, 'password': password});
  }

  static Future<AuthUser> login({required String email, required String password}) {
    return _authenticate('/auth/login', {'email': email, 'password': password});
  }

  // Called when the app starts. Returns the user if there is a saved session, or null if the user must log in
  static Future<AuthUser?> restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    final savedUser = prefs.getString(_userKey);
    if (token == null || savedUser == null) return null;

    _api.setToken(token);
    try {
      // Asks the backend if the token is still valid (it expires after 7 days)
      final user = AuthUser.fromJson(await _api.getJson('/auth/me') as Map<String, dynamic>);
      currentUser.value = user;
      return user;
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        await logout(); // expired or invalid token: the user has to log in again
        return null;
      }
      return _offlineUser(savedUser); // the server answered with another error: keep the saved session
    } catch (_) {
      // No internet or server down: keep the saved session so the app can still be used
      return _offlineUser(savedUser);
    }
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
    _api.setToken(null); // from now on no service sends the old token
    currentUser.value = null;
  }

  static AuthUser _offlineUser(String savedUser) {
    final user = AuthUser.fromJson(jsonDecode(savedUser) as Map<String, dynamic>);
    currentUser.value = user;
    return user;
  }

  // Shared by register and login: both answer {access_token, token_type, user}
  static Future<AuthUser> _authenticate(String path, Map<String, dynamic> body) async {
    final data = await _post(path, body);
    final token = data['access_token'] as String;
    final user = AuthUser.fromJson(data['user'] as Map<String, dynamic>);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    await prefs.setString(_userKey, jsonEncode(user.toJson()));
    _api.setToken(token);
    currentUser.value = user;
    return user;
  }

  // Sends the request and turns every possible failure into a message the user can understand
  static Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body) async {
    try {
      return await _api.postJson(path, body) as Map<String, dynamic>;
    } on ApiException catch (e) {
      throw AuthException(e.detail ?? _messageFor(e.statusCode));
    } on TimeoutException {
      throw AuthException('The server took too long to answer. Try again.');
    } catch (_) {
      throw AuthException('Could not connect to the server. Check your internet connection.');
    }
  }

  static String _messageFor(int statusCode) => switch (statusCode) {
        401 => 'Incorrect email or password',
        409 => 'An account with this email already exists',
        422 => 'Check the data you entered',
        _ => 'Something went wrong ($statusCode). Try again.',
      };
}
