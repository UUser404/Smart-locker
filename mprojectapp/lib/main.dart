import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'models/session.dart';
import 'services/api_service.dart';
import 'services/auth_service.dart';
import 'services/fcm_service.dart';
import 'screens/admin_home_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/login_screen.dart';

// Dihasilkan otomatis oleh `flutterfire configure`.
// Jalankan perintah itu dulu supaya file ini ada sebelum build.
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // WAJIB didaftarkan sebelum runApp supaya notifikasi tetap tertangani
  // saat app di-background atau ter-terminate.
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  runApp(const SmartLockerStaffApp());
}

class SmartLockerStaffApp extends StatelessWidget {
  const SmartLockerStaffApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Locker - Petugas',
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      home: const _StartupGate(),
    );
  }
}

/// Cek apakah ada sesi login tersimpan. Kalau ada, langsung arahkan sesuai
/// role (admin -> laporan, petugas -> dashboard + re-register token FCM).
/// Kalau belum ada, ke LoginScreen.
class _StartupGate extends StatefulWidget {
  const _StartupGate();

  @override
  State<_StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends State<_StartupGate> {
  late final ApiService _apiService = ApiService();
  late final AuthService _authService = AuthService(_apiService);
  late final FcmService _fcmService = FcmService(_apiService);
  Widget? _resolvedScreen;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  Future<void> _resolve() async {
    final session = await _authService.getSavedSession();

    if (session == null) {
      setState(() {
        _resolvedScreen = LoginScreen(
          authService: _authService,
          fcmService: _fcmService,
        );
      });
      return;
    }

    if (session.role == UserRole.petugas) {
      // Re-register token FCM tiap app dibuka (aman dipanggil berkali-kali),
      // jaga-jaga token berubah sejak sesi terakhir.
      await _fcmService.initAndRegister(session.nama);
    }

    setState(() {
      _resolvedScreen = session.role == UserRole.admin
          ? AdminHomeScreen(session: session)
          : DashboardScreen(fcmService: _fcmService, session: session);
    });
  }

  @override
  Widget build(BuildContext context) {
    return _resolvedScreen ??
        const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
