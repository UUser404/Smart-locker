import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/session.dart';
import 'api_service.dart';

const String _kPrefSession = 'auth_session';

class AuthService {
  final ApiService _api;

  AuthService(this._api);

  Future<AuthSession> login(String username, String password) async {
    final session = await _api.login(username: username, password: password);
    await _saveSession(session);
    return session;
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kPrefSession);
  }

  Future<AuthSession?> getSavedSession() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kPrefSession);
    if (raw == null) return null;
    try {
      return AuthSession.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      // Data korup/format lama -> anggap tidak ada sesi tersimpan.
      return null;
    }
  }

  Future<void> _saveSession(AuthSession session) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPrefSession, jsonEncode(session.toJson()));
  }
}
