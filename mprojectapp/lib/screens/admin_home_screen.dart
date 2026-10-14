import 'package:flutter/material.dart';
import '../models/locker.dart';
import '../models/rental_record.dart';
import '../models/session.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/fcm_service.dart';
import 'admin_analytics_screen.dart';
import 'admin_history_screen.dart';
import 'login_screen.dart';

class AdminHomeScreen extends StatefulWidget {
  final AuthSession session;

  const AdminHomeScreen({super.key, required this.session});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen>
    with WidgetsBindingObserver {
  late final ApiService _api;
  late final AuthService _authService;

  int _selectedIndex = 0;

  RentalStats? _stats;
  List<RentalRecord> _rentals = [];
  List<Locker> _lockers = [];
  bool _loading = true;
  String? _error;

  // Track state agar tidak refresh saat app masih loading/error
  DateTime? _lastFetch;

  @override
  void initState() {
    super.initState();

    // ⬇️ Register lifecycle observer
    WidgetsBinding.instance.addObserver(this);

    _api = ApiService();
    _api.setToken(widget.session.token);
    _authService = AuthService(_api);
    _loadReports();
  }

  @override
  void dispose() {
    // ⬇️ WAJIB unregister
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Dipanggil setiap kali app berubah lifecycle state
  /// (foreground/background/inactive/paused)
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // App kembali ke foreground
      // Refresh hanya kalau data terakhir fetch > 30 detik yang lalu
      // (biar tidak spam kalau user cepat buka-tutup app)
      final now = DateTime.now();
      if (_lastFetch == null || now.difference(_lastFetch!).inSeconds > 30) {
        debugPrint('[AdminHome] App resumed → auto-refresh');
        _loadReports(silent: true);
      } else {
        debugPrint('[AdminHome] App resumed → skip refresh (data masih fresh)');
      }
    }
  }

  Future<void> _loadReports({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final results = await Future.wait([
        _api.fetchLockers(),
        _api.fetchRentalReports(),
      ]);

      final lockers = results[0] as List<Locker>;
      final (stats, rentals) = results[1] as (RentalStats, List<RentalRecord>);

      if (!mounted) return;
      setState(() {
        _lockers = lockers;
        _stats = stats;
        _rentals = rentals;
        _loading = false;
        _lastFetch = DateTime.now(); // ⬅️ Catat waktu fetch
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (!silent) _error = 'Gagal memuat laporan: $e';
      });
    }
  }

  Future<void> _logout() async {
    await _authService.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => LoginScreen(
          authService: AuthService(ApiService()),
          fcmService: FcmService(ApiService()),
        ),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _rentals.isEmpty && _error == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_error != null && _rentals.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Dashboard Admin')),
        body: ListView(
          children: [
            const SizedBox(height: 80),
            const Icon(Icons.error_outline, color: Colors.red, size: 40),
            const SizedBox(height: 12),
            Center(child: Text(_error!)),
            const SizedBox(height: 24),
            Center(
              child: FilledButton.icon(
                onPressed: _loadReports,
                icon: const Icon(Icons.refresh),
                label: const Text('Coba Lagi'),
              ),
            ),
          ],
        ),
      );
    }

    final pages = [
      AdminAnalyticsScreen(
        session: widget.session,
        stats: _stats,
        rentals: _rentals,
        lockers: _lockers,
        onRefresh: _loadReports,
        onLogout: _logout,
      ),
      AdminHistoryScreen(
        session: widget.session,
        rentals: _rentals,
        onRefresh: _loadReports,
        onLogout: _logout,
      ),
    ];

    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() => _selectedIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.analytics_outlined),
            selectedIcon: Icon(Icons.analytics),
            label: 'Analitik',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Riwayat',
          ),
        ],
      ),
    );
  }
}
