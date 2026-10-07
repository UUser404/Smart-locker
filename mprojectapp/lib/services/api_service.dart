import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/locker.dart';
import '../models/session.dart';
import '../models/rental_record.dart';

// === KONFIGURASI BACKEND ===
// Ganti sesuai domain backend kamu. Jangan pakai trailing slash.
const String kApiBaseUrl = 'https://smart-locker-backend-a2ck.onrender.com/api';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  ApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

class ApiService {
  final http.Client _client;
  String? _token; // diset setelah login

  ApiService({http.Client? client}) : _client = client ?? http.Client();

  Uri _uri(String path) => Uri.parse('$kApiBaseUrl$path');

  /// Set token setelah login berhasil.
  void setToken(String? token) => _token = token;

  /// Header default + Authorization kalau ada token.
  Map<String, String> _headers({bool json = true}) {
    final h = <String, String>{};
    if (json) h['Content-Type'] = 'application/json';
    if (_token != null && _token!.isNotEmpty) {
      h['Authorization'] = 'Bearer $_token';
    }
    return h;
  }

  // ==================== AUTH ====================

  /// POST /api/auth/login
  Future<AuthSession> login({
    required String username,
    required String password,
  }) async {
    final res = await _client
        .post(
          _uri('/auth/login'),
          headers: _headers(),
          body: jsonEncode({'username': username, 'password': password}),
        )
        .timeout(const Duration(seconds: 60)); // Render free tier cold start

    if (res.statusCode == 401) {
      throw ApiException('Username atau password salah', statusCode: 401);
    }
    if (res.statusCode != 200) {
      throw ApiException(
        'Gagal login (${res.statusCode})',
        statusCode: res.statusCode,
      );
    }

    final session = AuthSession.fromJson(
      jsonDecode(res.body) as Map<String, dynamic>,
    );

    // Simpan token untuk request berikutnya
    setToken(session.token);
    return session;
  }

  // ==================== ADMIN: LOCKERS ====================

  /// GET /api/admin/lockers  (butuh JWT)
  Future<List<Locker>> fetchLockers() async {
    final res = await _client
        .get(_uri('/admin/lockers'), headers: _headers(json: false))
        .timeout(const Duration(seconds: 30));

    if (res.statusCode == 401) {
      throw ApiException('Sesi berakhir, silakan login ulang', statusCode: 401);
    }
    if (res.statusCode != 200) {
      throw ApiException(
        'Gagal memuat locker (${res.statusCode})',
        statusCode: res.statusCode,
      );
    }

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final list = (body['lockers'] as List<dynamic>? ?? []);
    return list.map((e) => Locker.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// POST /api/admin/lockers/{id}/resolve  (butuh JWT)
  Future<String> resolveLocker(String lockerId) async {
    final res = await _client
        .post(
          _uri('/admin/lockers/$lockerId/resolve'),
          headers: _headers(json: false),
        )
        .timeout(const Duration(seconds: 30));

    if (res.statusCode == 404) {
      throw ApiException('Locker tidak ditemukan', statusCode: 404);
    }
    if (res.statusCode == 409) {
      throw ApiException(
        'Locker tidak dalam status needs_attention',
        statusCode: 409,
      );
    }
    if (res.statusCode != 200) {
      throw ApiException(
        'Gagal resolve locker (${res.statusCode})',
        statusCode: res.statusCode,
      );
    }

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return body['new_status'] as String? ?? 'empty';
  }

  // ==================== ADMIN: REPORTS ====================

  /// GET /api/admin/reports/rentals  (butuh JWT, role admin)
  Future<(RentalStats, List<RentalRecord>)> fetchRentalReports() async {
    final res = await _client
        .get(_uri('/admin/reports/rentals'), headers: _headers(json: false))
        .timeout(const Duration(seconds: 30));

    if (res.statusCode == 403) {
      throw ApiException('Akses ditolak (bukan admin)', statusCode: 403);
    }
    if (res.statusCode == 401) {
      throw ApiException('Sesi berakhir, silakan login ulang', statusCode: 401);
    }
    if (res.statusCode != 200) {
      throw ApiException(
        'Gagal memuat laporan (${res.statusCode})',
        statusCode: res.statusCode,
      );
    }

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final stats = RentalStats.fromJson(body['stats'] as Map<String, dynamic>);
    final rentals = (body['rentals'] as List<dynamic>)
        .map((e) => RentalRecord.fromJson(e as Map<String, dynamic>))
        .toList();
    return (stats, rentals);
  }

  // ==================== DEVICE (FCM) ====================

  /// POST /api/admin/register-device  (TANPA auth)
  Future<void> registerDevice({
    required String fcmToken,
    required String petugasId,
  }) async {
    final res = await _client
        .post(
          _uri('/admin/register-device'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'fcm_token': fcmToken, 'petugas_id': petugasId}),
        )
        .timeout(const Duration(seconds: 30));

    if (res.statusCode != 200) {
      throw ApiException(
        'Gagal mendaftarkan device (${res.statusCode})',
        statusCode: res.statusCode,
      );
    }
  }
}
