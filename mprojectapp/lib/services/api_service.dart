import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/locker.dart';
import '../models/session.dart';
import '../models/rental_record.dart';

/// Ganti sesuai domain backend kamu.
/// Jangan pakai trailing slash.
const String kApiBaseUrl = 'https://<domain-backend>/api';

/// Set false kalau backend asli sudah siap dipakai.
/// Selama true, ApiService tidak melakukan HTTP request sama sekali —
/// semua data dari _MockBackend di bawah (in-memory, reset tiap app dibuka).
const bool kUseMockData = true;

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  ApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

class ApiService {
  final http.Client _client;

  ApiService({http.Client? client}) : _client = client ?? http.Client();

  Uri _uri(String path) => Uri.parse('$kApiBaseUrl$path');

  /// POST /api/auth/login
  /// PROPOSAL — belum ada di docs/API.md, perlu dikonfirmasi & ditambahkan
  /// Galuh di backend sebelum kUseMockData dimatikan.
  /// Body: { username, password }
  /// Response sukses: { token, role: "admin"|"petugas", nama }
  Future<AuthSession> login({
    required String username,
    required String password,
  }) async {
    if (kUseMockData) {
      return _MockBackend.instance.login(username, password);
    }

    final res = await _client.post(
      _uri('/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'password': password}),
    );

    if (res.statusCode != 200) {
      throw ApiException(
        'Username atau password salah',
        statusCode: res.statusCode,
      );
    }

    return AuthSession.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  /// GET /api/admin/reports/rentals
  /// PROPOSAL — belum ada di docs/API.md, perlu dikonfirmasi & ditambahkan
  /// Galuh di backend. Dipakai layar laporan/statistik role Admin.
  /// Response: { stats: {...}, rentals: [...] }
  Future<(RentalStats, List<RentalRecord>)> fetchRentalReports() async {
    if (kUseMockData) return _MockBackend.instance.fetchRentalReports();

    final res = await _client.get(_uri('/admin/reports/rentals'));

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

  /// GET /api/admin/lockers
  Future<List<Locker>> fetchLockers() async {
    if (kUseMockData) return _MockBackend.instance.fetchLockers();

    final res = await _client.get(_uri('/admin/lockers'));

    if (res.statusCode != 200) {
      throw ApiException(
        'Gagal memuat status locker (${res.statusCode})',
        statusCode: res.statusCode,
      );
    }

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final list = (body['lockers'] as List<dynamic>? ?? []);
    return list.map((e) => Locker.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// POST /api/admin/lockers/{locker_id}/resolve
  /// Mengembalikan status locker yang baru ("empty").
  Future<String> resolveLocker(String lockerId) async {
    if (kUseMockData) return _MockBackend.instance.resolveLocker(lockerId);

    final res = await _client.post(_uri('/admin/lockers/$lockerId/resolve'));

    if (res.statusCode != 200) {
      throw ApiException(
        'Gagal menyelesaikan locker $lockerId (${res.statusCode})',
        statusCode: res.statusCode,
      );
    }

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return body['new_status'] as String? ?? 'empty';
  }

  /// POST /api/admin/register-device
  /// Dipanggil sekali saat app pertama kali dibuka/login, mendaftarkan
  /// token FCM milik HP petugas.
  Future<void> registerDevice({
    required String fcmToken,
    required String petugasId,
  }) async {
    if (kUseMockData) {
      return _MockBackend.instance.registerDevice(fcmToken, petugasId);
    }

    final res = await _client.post(
      _uri('/admin/register-device'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'fcm_token': fcmToken, 'petugas_id': petugasId}),
    );

    if (res.statusCode != 200) {
      throw ApiException(
        'Gagal mendaftarkan device (${res.statusCode})',
        statusCode: res.statusCode,
      );
    }
  }
}

/// Backend palsu in-memory supaya UI bisa didemo tanpa server asli.
/// Data reset setiap app di-restart. Hapus class ini kapan pun kamu
/// sudah tidak butuh mode mock (dan set kUseMockData = false).
class _MockBackend {
  _MockBackend._();
  static final _MockBackend instance = _MockBackend._();

  final List<Locker> _lockers = [
    Locker(lockerId: 'locker_01', status: LockerStatus.empty),
    Locker(
      lockerId: 'locker_02',
      status: LockerStatus.occupied,
      elapsedSeconds: 620,
    ),
    Locker(
      lockerId: 'locker_03',
      status: LockerStatus.needsAttention,
      unlockedSince: DateTime.now().toUtc().subtract(
        const Duration(minutes: 7),
      ),
    ),
    Locker(lockerId: 'locker_04', status: LockerStatus.empty),
  ];

  Future<List<Locker>> fetchLockers() async {
    await Future.delayed(const Duration(milliseconds: 400));
    // Simulasi durasi occupied yang terus jalan tiap kali di-fetch.
    for (var i = 0; i < _lockers.length; i++) {
      final l = _lockers[i];
      if (l.status == LockerStatus.occupied) {
        _lockers[i] = Locker(
          lockerId: l.lockerId,
          status: l.status,
          elapsedSeconds: (l.elapsedSeconds ?? 0) + 10,
        );
      }
    }
    return List.unmodifiable(_lockers);
  }

  Future<String> resolveLocker(String lockerId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final index = _lockers.indexWhere((l) => l.lockerId == lockerId);
    if (index != -1) {
      _lockers[index] = Locker(lockerId: lockerId, status: LockerStatus.empty);
    }
    return 'empty';
  }

  Future<void> registerDevice(String fcmToken, String petugasId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    // ignore: avoid_print
    print('[MOCK] registerDevice: petugasId=$petugasId token=$fcmToken');
  }

  // --- Kredensial dummy untuk testing sebelum backend auth beneran ada ---
  // Username: admin   / Password: admin123   -> role admin
  // Username: petugas / Password: petugas123 -> role petugas
  final Map<String, Map<String, String>> _users = {
    'admin': {'password': 'admin123', 'role': 'admin', 'nama': 'Admin STTI'},
    'petugas': {
      'password': 'petugas123',
      'role': 'petugas',
      'nama': 'Petugas Keamanan',
    },
  };

  Future<AuthSession> login(String username, String password) async {
    await Future.delayed(const Duration(milliseconds: 500));
    final user = _users[username];
    if (user == null || user['password'] != password) {
      throw ApiException('Username atau password salah');
    }
    return AuthSession(
      token: 'mock-token-$username',
      role: userRoleFromString(user['role']!),
      nama: user['nama']!,
    );
  }

  Future<(RentalStats, List<RentalRecord>)> fetchRentalReports() async {
    await Future.delayed(const Duration(milliseconds: 400));
    final now = DateTime.now().toUtc();
    final rentals = [
      RentalRecord(
        rentalId: 'rnt_2001',
        lockerId: 'locker_01',
        nama: 'Budi Santoso',
        noHp: '0812xxxxxx01',
        startedAt: now.subtract(const Duration(hours: 5)),
        endedAt: now.subtract(const Duration(hours: 4, minutes: 42)),
        totalDurationSeconds: 1080,
      ),
      RentalRecord(
        rentalId: 'rnt_2002',
        lockerId: 'locker_03',
        nama: 'Siti Aminah',
        noHp: '0813xxxxxx02',
        startedAt: now.subtract(const Duration(hours: 3)),
        endedAt: now.subtract(const Duration(hours: 2, minutes: 50)),
        totalDurationSeconds: 600,
      ),
      RentalRecord(
        rentalId: 'rnt_2003',
        lockerId: 'locker_02',
        nama: 'Andi Wijaya',
        noHp: '0814xxxxxx03',
        startedAt: now.subtract(const Duration(minutes: 12)),
        // masih berjalan -> endedAt & totalDurationSeconds null
      ),
    ];

    final stats = RentalStats(
      totalRentals: rentals.length,
      avgDurationSeconds: 840,
      busiestLockerId: 'locker_02',
    );

    return (stats, rentals);
  }
}
