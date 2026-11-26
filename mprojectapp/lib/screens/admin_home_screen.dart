import 'package:flutter/material.dart';

import '../models/audit_log_record.dart';
import '../models/controller_status.dart';
import '../models/locker.dart';
import '../models/rental_record.dart';
import '../models/session.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/fcm_service.dart';
import '../theme/app_theme.dart';
import '../theme/app_tokens.dart';
import '../widgets/design_system_widgets.dart';
import 'admin_analytics_screen.dart';
import 'admin_audit_screen.dart';
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

  int _mobileIndex = 0;
  int _webIndex = 0;
  RentalStats? _stats;
  List<RentalRecord> _rentals = [];
  List<Locker> _lockers = [];
  List<ControllerStatus> _deviceStatuses = [];
  List<AuditLogRecord> _auditLogs = [];
  bool _loading = true;
  bool _auditLoading = true;
  String? _error;
  String? _deviceError;
  String? _auditError;
  DateTime? _lastFetch;
  bool _handlingExpiredSession = false;

  static const _webDestinations = [
    _AdminDestination(Icons.dashboard_outlined, 'Ringkasan'),
    _AdminDestination(Icons.grid_view_outlined, 'Locker & Perangkat'),
    _AdminDestination(Icons.receipt_long_outlined, 'Riwayat Sewa'),
    _AdminDestination(Icons.shield_outlined, 'Log Audit'),
    _AdminDestination(Icons.groups_outlined, 'Petugas'),
    _AdminDestination(Icons.settings_outlined, 'Pengaturan'),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _api = ApiService()..setToken(widget.session.token);
    _authService = AuthService(_api);
    _loadReports();
    _loadAudit();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final now = DateTime.now();
      if (_lastFetch == null || now.difference(_lastFetch!).inSeconds > 30) {
        _loadReports(silent: true);
      }
    }
  }

  Future<void> _loadReports({bool silent = false}) async {
    if (!silent && mounted) {
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
      var devices = <ControllerStatus>[];
      String? deviceError;
      try {
        devices = await _api.fetchControllerStatuses();
      } catch (e) {
        if (e is ApiException && e.statusCode == 401) rethrow;
        deviceError = 'Gagal memuat status ESP32: $e';
      }
      if (!mounted) return;
      setState(() {
        _lockers = lockers;
        _stats = stats;
        _rentals = rentals;
        _deviceStatuses = devices;
        _deviceError = deviceError;
        _loading = false;
        _error = null;
        _lastFetch = DateTime.now();
      });
    } catch (e) {
      if (!mounted) return;
      if (e is ApiException && e.statusCode == 401) {
        await _handleExpiredSession();
        return;
      }
      setState(() {
        _loading = false;
        if (!silent) _error = 'Gagal memuat data: $e';
      });
    }
  }

  Future<void> _loadAudit() async {
    if (mounted) {
      setState(() {
        _auditLoading = true;
        _auditError = null;
      });
    }

    try {
      final logs = await _api.fetchAuditLogs();
      if (!mounted) return;
      setState(() {
        _auditLogs = logs;
        _auditLoading = false;
        _auditError = null;
      });
    } catch (e) {
      if (!mounted) return;
      if (e is ApiException && e.statusCode == 401) {
        await _handleExpiredSession();
        return;
      }
      setState(() {
        _auditLoading = false;
        _auditError = 'Gagal memuat log audit: $e';
      });
    }
  }

  Future<void> _handleExpiredSession() async {
    if (_handlingExpiredSession) return;
    _handlingExpiredSession = true;
    await _authService.logout();
    if (!mounted) return;

    final loginApi = ApiService();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => LoginScreen(
          authService: AuthService(loginApi),
          fcmService: FcmService(loginApi),
          notice: 'Sesi login kedaluwarsa. Silakan masuk kembali.',
        ),
      ),
      (route) => false,
    );
  }

  Future<void> _logout() async {
    await _authService.logout();
    if (!mounted) return;
    final loginApi = ApiService();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => LoginScreen(
          authService: AuthService(loginApi),
          fcmService: FcmService(loginApi),
        ),
      ),
      (route) => false,
    );
  }

  Widget _selectedWebPage() {
    return switch (_webIndex) {
      0 => _buildSummary(),
      1 => _buildLockerPage(),
      2 => _buildHistory(),
      3 => _buildAudit(),
      4 => const _UnavailableAdminPage(
        title: 'Manajemen Petugas',
        message: 'Data petugas dan pengelolaannya belum tersedia di API.',
      ),
      _ => _buildAccountPage(),
    };
  }

  Widget _selectedMobilePage() {
    return switch (_mobileIndex) {
      0 => _buildSummary(),
      1 => _buildHistory(),
      2 => _buildAudit(),
      _ => _buildAccountPage(),
    };
  }

  Widget _buildSummary() => AdminAnalyticsScreen(
    stats: _stats,
    rentals: _rentals,
    lockers: _lockers,
    deviceStatuses: _deviceStatuses,
    loading: _loading,
    deviceError: _deviceError,
    error: _error,
    onRefresh: _loadReports,
  );

  Widget _buildLockerPage() => AdminAnalyticsScreen(
    stats: _stats,
    rentals: _rentals,
    lockers: _lockers,
    deviceStatuses: _deviceStatuses,
    loading: _loading,
    deviceError: _deviceError,
    error: _error,
    onRefresh: _loadReports,
    showLockerListOnly: true,
  );

  Widget _buildHistory() =>
      AdminHistoryScreen(rentals: _rentals, onRefresh: _loadReports);

  Widget _buildAudit() => AdminAuditScreen(
    logs: _auditLogs,
    loading: _auditLoading,
    error: _auditError,
    onRefresh: _loadAudit,
  );

  Widget _buildAccountPage() => _AdminAccountPage(
    session: widget.session,
    onLogout: _logout,
    showSettingsNotice: true,
  );

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isExpanded =
            screenClassOf(constraints.maxWidth) == ScreenClass.expanded;
        if (isExpanded) {
          return Scaffold(
            body: SafeArea(
              child: Row(
                children: [
                  SizedBox(
                    width: AppSize.sidebar,
                    child: _AdminSidebar(
                      selectedIndex: _webIndex,
                      destinations: _webDestinations,
                      name: widget.session.nama,
                      onSelected: (index) => setState(() => _webIndex = index),
                    ),
                  ),
                  Expanded(child: _selectedWebPage()),
                ],
              ),
            ),
          );
        }

        return Scaffold(
          body: _selectedMobilePage(),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _mobileIndex,
            onDestinationSelected: (index) =>
                setState(() => _mobileIndex = index),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard),
                label: 'Ringkasan',
              ),
              NavigationDestination(
                icon: Icon(Icons.receipt_long_outlined),
                selectedIcon: Icon(Icons.receipt_long),
                label: 'Riwayat',
              ),
              NavigationDestination(
                icon: Icon(Icons.shield_outlined),
                selectedIcon: Icon(Icons.shield),
                label: 'Log',
              ),
              NavigationDestination(
                icon: Icon(Icons.menu),
                selectedIcon: Icon(Icons.menu_open),
                label: 'Menu',
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AdminDestination {
  const _AdminDestination(this.icon, this.label);

  final IconData icon;
  final String label;
}

class _AdminSidebar extends StatelessWidget {
  const _AdminSidebar({
    required this.selectedIndex,
    required this.destinations,
    required this.name,
    required this.onSelected,
  });

  final int selectedIndex;
  final List<_AdminDestination> destinations;
  final String name;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.neutralInverse,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.s6,
              AppSpace.s6,
              AppSpace.s4,
              AppSpace.s8,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Smart Locker',
                  style: AppType.title.copyWith(
                    color: AppColors.neutralOnInverse,
                  ),
                ),
                SizedBox(height: AppSpace.s1),
                Text(
                  'Admin Console',
                  style: AppType.overline.copyWith(
                    color: AppColors.neutralOnInverseMuted,
                  ),
                ),
              ],
            ),
          ),
          for (var index = 0; index < destinations.length; index++)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpace.s2,
                vertical: AppSpace.s1,
              ),
              child: ListTile(
                selected: selectedIndex == index,
                selectedTileColor: AppColors.brandPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.field),
                ),
                leading: Icon(
                  destinations[index].icon,
                  color: selectedIndex == index
                      ? AppColors.neutralOnInverse
                      : AppColors.neutralOnInverseMuted,
                ),
                title: Text(
                  destinations[index].label,
                  style: TextStyle(
                    color: selectedIndex == index
                        ? AppColors.neutralOnInverse
                        : AppColors.neutralOnInverseMuted,
                    fontWeight: selectedIndex == index
                        ? FontWeight.w800
                        : FontWeight.w600,
                  ),
                ),
                onTap: () => onSelected(index),
              ),
            ),
          const Spacer(),
          const Divider(color: AppColors.neutralInverseRaised),
          Padding(
            padding: const EdgeInsets.all(AppSpace.s4),
            child: Row(
              children: [
                const CircleAvatar(
                  backgroundColor: AppColors.neutralInverseRaised,
                  child: Icon(Icons.person, color: AppColors.neutralOnInverse),
                ),
                const SizedBox(width: AppSpace.s2),
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(
                      color: AppColors.neutralOnInverse,
                      fontWeight: FontWeight.w700,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminAccountPage extends StatelessWidget {
  const _AdminAccountPage({
    required this.session,
    required this.onLogout,
    required this.showSettingsNotice,
  });

  final AuthSession session;
  final Future<void> Function() onLogout;
  final bool showSettingsNotice;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Menu')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpace.s4),
        children: [
          Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: AppColors.brandPrimaryContainer,
                child: Text(
                  session.nama.isEmpty ? '?' : session.nama[0].toUpperCase(),
                  style: const TextStyle(
                    color: AppColors.brandPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              title: Text(session.nama),
              subtitle: const Text('Administrator'),
            ),
          ),
          if (showSettingsNotice)
            const Card(
              child: ListTile(
                leading: Icon(Icons.info_outline),
                title: Text('Pengaturan'),
                subtitle: Text('Pengaturan sistem belum tersedia.'),
              ),
            ),
          const SizedBox(height: AppSpace.s3),
          OutlinedButton.icon(
            onPressed: onLogout,
            icon: const Icon(Icons.logout),
            label: const Text('Keluar'),
          ),
        ],
      ),
    );
  }
}

class _UnavailableAdminPage extends StatelessWidget {
  const _UnavailableAdminPage({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: DesignEmptyState(
        icon: Icons.construction_outlined,
        title: 'Belum tersedia',
        message: message,
      ),
    );
  }
}
