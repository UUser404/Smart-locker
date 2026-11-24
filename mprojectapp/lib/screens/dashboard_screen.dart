import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import '../models/locker.dart';
import '../models/session.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/fcm_service.dart';
import '../theme/app_theme.dart';
import '../theme/app_tokens.dart';
import '../widgets/design_system_widgets.dart';
import 'login_screen.dart';
import 'petugas_locker_screens.dart';

class DashboardScreen extends StatefulWidget {
  final FcmService fcmService;
  final AuthSession session;

  const DashboardScreen({
    super.key,
    required this.fcmService,
    required this.session,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with WidgetsBindingObserver {
  late final ApiService _api;
  late final AuthService _authService;

  List<Locker> _lockers = [];
  bool _loading = true;
  String? _error;
  Timer? _pollTimer;
  StreamSubscription? _fgMessageSub;
  StreamSubscription? _openedAppSub;
  DateTime? _lastFetch;
  bool _handlingExpiredSession = false;
  int _selectedTab = 0;

  // Anti spam snackbar: track locker yang sudah di-snackbar pada sesi ini.
  // Reset saat locker keluar dari needs_attention.
  final Set<String> _snackbarShownFor = {};

  // Untuk accordion in-app: SnackBarController per locker
  final Map<String, ScaffoldFeatureController<SnackBar, SnackBarClosedReason>>
  _activeSnackbars = {};

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    _api = ApiService();
    _api.setToken(widget.session.token);
    _authService = AuthService(_api);

    _loadLockers();

    _pollTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _loadLockers(silent: true);
    });

    // FCM foreground → snackbar accordion
    _fgMessageSub = widget.fcmService.onForegroundMessage.listen((message) {
      final lockerId = message.data['locker_id'];
      final mode = message.data['mode'] ?? 'initial';
      if (mounted && lockerId != null) {
        _showLockerSnackBar(
          lockerId: lockerId as String,
          body:
              message.notification?.body ?? 'Locker $lockerId perlu perhatian',
          isReminder: mode == 'reminder',
        );
      }
      _loadLockers(silent: true);
    });

    _openedAppSub = widget.fcmService.onMessageOpenedApp.listen((_) {
      _loadLockers(silent: true);
    });

    _checkInitialMessage();
  }

  Future<void> _checkInitialMessage() async {
    try {
      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null) {
        debugPrint('[Dashboard] App dibuka dari notif: ${initial.data}');
        _loadLockers(silent: true);
      }
    } catch (e) {
      debugPrint('[Dashboard] getInitialMessage error: $e');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollTimer?.cancel();
    _fgMessageSub?.cancel();
    _openedAppSub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final now = DateTime.now();
      if (_lastFetch == null || now.difference(_lastFetch!).inSeconds > 30) {
        debugPrint('[Dashboard] App resumed → refresh');
        _loadLockers(silent: true);
      }
    }
  }

  Future<void> _loadLockers({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final lockers = await _api.fetchLockers();
      if (!mounted) return;
      setState(() {
        _lockers = lockers;
        _loading = false;
        _error = null;
        _lastFetch = DateTime.now();
      });

      // Catch-up in-app: tampilkan snackbar untuk locker needs_attention
      // yang belum pernah di-snackbar pada sesi ini.
      _checkCatchUpSnackbars();
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

  Future<void> _handleExpiredSession() async {
    if (_handlingExpiredSession) return;
    _handlingExpiredSession = true;

    await _authService.logout();
    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => LoginScreen(
          authService: _authService,
          fcmService: widget.fcmService,
          notice: 'Sesi login kedaluwarsa. Silakan masuk kembali.',
        ),
      ),
      (route) => false,
    );
    unawaited(widget.fcmService.unregister());
  }

  /// Tampilkan snackbar catch-up untuk locker needs_attention yang belum
  /// di-snackbar. Juga bersihkan tracker untuk locker yang sudah resolved.
  void _checkCatchUpSnackbars() {
    final needsAttentionIds = _lockers
        .where((l) => l.status == LockerStatus.needsAttention)
        .map((l) => l.lockerId)
        .toSet();

    // Bersihkan tracker untuk locker yang sudah tidak needs_attention
    _snackbarShownFor.removeWhere((id) => !needsAttentionIds.contains(id));
    _activeSnackbars.removeWhere((id, _) => !needsAttentionIds.contains(id));

    // Tampilkan snackbar untuk yang belum ditampilkan
    for (final locker in _lockers) {
      if (locker.status != LockerStatus.needsAttention) continue;
      if (_snackbarShownFor.contains(locker.lockerId)) continue;

      _snackbarShownFor.add(locker.lockerId);
      _showLockerSnackBar(
        lockerId: locker.lockerId,
        body:
            'Locker ${locker.lockerId} — pintu terbuka sejak '
            '${locker.needsAttentionSinceLabel}. Segera cek.',
        isReminder: false,
      );
    }
  }

  /// Tampilkan snackbar accordion: kalau sudah ada snackbar untuk locker
  /// yang sama, tutup dulu lalu tampilkan versi baru (update body).
  void _showLockerSnackBar({
    required String lockerId,
    required String body,
    required bool isReminder,
  }) {
    if (!mounted) return;

    // Accordion: tutup snackbar lama untuk locker ini (kalau ada)
    _closeLockerSnackBar(lockerId);

    final controller = ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(body),
        duration: const Duration(seconds: 5),
        backgroundColor: isReminder
            ? AppColors.warningMain
            : AppColors.dangerMain,
        action: SnackBarAction(
          label: 'Lihat',
          textColor: AppColors.neutralOnInverse,
          onPressed: () {
            // Scroll ke atas / refresh — di sini cukup refresh
            _loadLockers(silent: true);
          },
        ),
      ),
    );
    _activeSnackbars[lockerId] = controller;

    // Hapus dari tracker begitu snackbar tertutup (duration habis / di-swipe),
    // supaya tracker hanya berisi snackbar yang masih hidup.
    controller.closed.then((_) {
      if (identical(_activeSnackbars[lockerId], controller)) {
        _activeSnackbars.remove(lockerId);
      }
    });
  }

  /// Tutup snackbar milik satu locker dengan aman.
  ///
  /// `ScaffoldFeatureController.close()` melempar `Bad state: No element`
  /// (assert `_snackBars.first`) kalau snackbar itu sudah hilang sendiri
  /// karena duration habis — dan duration kita cuma 5 detik, sedangkan
  /// reminder datang tiap 60 detik.
  void _closeLockerSnackBar(String lockerId) {
    final controller = _activeSnackbars.remove(lockerId);
    if (controller == null) return;
    try {
      controller.close();
    } catch (e) {
      debugPrint('[Dashboard] close snackbar $lockerId diabaikan: $e');
    }
  }

  Future<void> _logout() async {
    await widget.fcmService.unregister();
    await _authService.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => LoginScreen(
          authService: AuthService(ApiService()),
          fcmService: widget.fcmService,
        ),
      ),
      (route) => false,
    );
  }

  Future<void> _openLocker(Locker locker) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LockerDetailScreen(
          locker: locker,
          onHandle: () => _openHandling(locker),
        ),
      ),
    );
    if (mounted) _loadLockers(silent: true);
  }

  Future<bool> _openHandling(Locker locker) async {
    final resolved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => LockerHandlingScreen(
          locker: locker,
          onResolve: () => _resolveLocker(locker),
        ),
      ),
    );
    return resolved == true;
  }

  Future<void> _resolveLocker(Locker locker) async {
    try {
      await _api.resolveLocker(locker.lockerId);
      if (!mounted) return;

      _closeLockerSnackBar(locker.lockerId);
      _snackbarShownFor.remove(locker.lockerId);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${locker.lockerId} ditandai kosong')),
      );
      await _loadLockers(silent: true);
    } catch (e) {
      if (!mounted) return;
      if (e is ApiException && e.statusCode == 401) {
        await _handleExpiredSession();
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal menyelesaikan locker: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _selectedTab == 0
                  ? 'Smart Locker'
                  : _selectedTab == 1
                  ? 'Riwayat'
                  : 'Akun',
              style: AppType.title,
            ),
            Text(
              _selectedTab == 0
                  ? 'Petugas · ${widget.session.nama}'
                  : 'Petugas',
              style: AppType.caption.copyWith(
                color: AppColors.neutralTextMuted,
              ),
            ),
          ],
        ),
        actions: [
          if (_selectedTab != 2)
            IconButton(
              onPressed: () => _loadLockers(),
              icon: const Icon(Icons.refresh),
              tooltip: 'Muat ulang',
            ),
        ],
      ),
      body: _buildSelectedBody(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedTab,
        onDestinationSelected: (index) => setState(() => _selectedTab = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.grid_view_outlined),
            selectedIcon: Icon(Icons.grid_view_rounded),
            label: 'Locker',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: 'Riwayat',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Akun',
          ),
        ],
      ),
    );
  }

  int _countByStatus(LockerStatus s) =>
      _lockers.where((l) => l.status == s).length;

  Widget _buildSelectedBody() {
    if (_loading && _lockers.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && _lockers.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadLockers,
        child: ListView(
          children: [
            const SizedBox(height: 120),
            DesignEmptyState(
              icon: Icons.cloud_off_outlined,
              title: 'Data locker tidak dapat dimuat',
              message: _error!,
            ),
            const SizedBox(height: AppSpace.s4),
            Center(
              child: OutlinedButton.icon(
                onPressed: _loadLockers,
                icon: const Icon(Icons.refresh),
                label: const Text('Coba lagi'),
              ),
            ),
          ],
        ),
      );
    }

    return switch (_selectedTab) {
      0 => _buildLockerHome(),
      1 => const DesignEmptyState(
        icon: Icons.history,
        title: 'Riwayat belum tersedia',
        message: 'Server belum menyediakan endpoint riwayat tindakan Petugas.',
      ),
      _ => _buildAccountPage(),
    };
  }

  Widget _buildLockerHome() {
    final attention = _lockers
        .where((locker) => locker.status == LockerStatus.needsAttention)
        .toList();
    final lockerCards = LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 700 ? 2 : 1;
        if (columns == 1) {
          return Column(
            children: _lockers
                .map(
                  (locker) => LockerSummaryCard(
                    locker: locker,
                    onTap: () => _openLocker(locker),
                  ),
                )
                .toList(),
          );
        }
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _lockers.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisExtent: 156,
            crossAxisSpacing: AppSpace.s3,
            mainAxisSpacing: AppSpace.s2,
          ),
          itemBuilder: (context, index) {
            final locker = _lockers[index];
            return LockerSummaryCard(
              locker: locker,
              onTap: () => _openLocker(locker),
            );
          },
        );
      },
    );

    return RefreshIndicator(
      onRefresh: _loadLockers,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppSize.contentMax),
          child: ListView(
            padding: const EdgeInsets.all(AppSpace.s4),
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  return GridView.count(
                    crossAxisCount: 3,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: AppSpace.s2,
                    crossAxisSpacing: AppSpace.s2,
                    childAspectRatio: constraints.maxWidth >= 700 ? 2.4 : 1.25,
                    children: [
                      DesignMetricCard(
                        label: 'Kosong',
                        value: '${_countByStatus(LockerStatus.empty)}',
                        style: AppStatus.success,
                        valueOnTop: true,
                      ),
                      DesignMetricCard(
                        label: 'Disewa',
                        value: '${_countByStatus(LockerStatus.occupied)}',
                        style: AppStatus.info,
                        valueOnTop: true,
                      ),
                      DesignMetricCard(
                        label: 'Perhatian',
                        value: '${attention.length}',
                        style: AppStatus.warning,
                        highlighted: attention.isNotEmpty,
                        valueOnTop: true,
                      ),
                    ],
                  );
                },
              ),
              if (attention.isNotEmpty) ...[
                const SizedBox(height: AppSpace.s6),
                DesignSectionHeader(
                  title: 'Perlu tindakan',
                  trailing: DesignStatusBadge(
                    label: '${attention.length}',
                    style: AppStatus.warning,
                  ),
                ),
                const SizedBox(height: AppSpace.s2),
                ...attention.map(
                  (locker) => _AttentionCard(
                    locker: locker,
                    onTap: () => _openLocker(locker),
                    onHandle: () => _openLocker(locker),
                  ),
                ),
              ],
              const SizedBox(height: AppSpace.s6),
              const DesignSectionHeader(title: 'Semua locker'),
              const SizedBox(height: AppSpace.s2),
              if (_lockers.isEmpty)
                const DesignEmptyState(
                  icon: Icons.inventory_2_outlined,
                  title: 'Belum ada data locker',
                  message: 'Tarik layar ke bawah untuk memuat ulang.',
                )
              else
                lockerCards,
              const SizedBox(height: AppSpace.s4),
              Container(
                padding: const EdgeInsets.all(AppSpace.s4),
                decoration: BoxDecoration(
                  color: AppColors.neutralFillMuted,
                  borderRadius: BorderRadius.circular(AppRadius.field),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AKTIVITAS TERAKHIR',
                      style: AppType.overline.copyWith(
                        color: AppColors.neutralTextMuted,
                      ),
                    ),
                    const SizedBox(height: AppSpace.s2),
                    Text(
                      'Riwayat kejadian belum tersedia dari API.',
                      style: AppType.caption.copyWith(
                        color: AppColors.neutralTextBody,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAccountPage() {
    return ListView(
      padding: const EdgeInsets.all(AppSpace.s4),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.s4),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: AppColors.brandPrimaryContainer,
                  child: Text(
                    widget.session.nama.isEmpty
                        ? '?'
                        : widget.session.nama[0].toUpperCase(),
                    style: AppType.title.copyWith(
                      color: AppColors.brandPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpace.s3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.session.nama, style: AppType.subtitle),
                      const SizedBox(height: AppSpace.s1),
                      Text(
                        'Petugas',
                        style: AppType.caption.copyWith(
                          color: AppColors.neutralTextMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpace.s3),
        OutlinedButton.icon(
          onPressed: _logout,
          icon: const Icon(Icons.logout),
          label: const Text('Keluar'),
        ),
      ],
    );
  }
}

class _AttentionCard extends StatelessWidget {
  const _AttentionCard({
    required this.locker,
    required this.onTap,
    required this.onHandle,
  });

  final Locker locker;
  final VoidCallback onTap;
  final VoidCallback onHandle;

  @override
  Widget build(BuildContext context) {
    final openedAt = locker.needsAttentionSince ?? locker.unlockedSince;
    final elapsedSeconds = openedAt == null
        ? null
        : DateTime.now().difference(openedAt).inSeconds;
    final safeElapsedSeconds = elapsedSeconds == null || elapsedSeconds < 0
        ? null
        : elapsedSeconds;
    final elapsedLabel = safeElapsedSeconds == null
        ? '--:--'
        : '${(safeElapsedSeconds ~/ 60).toString().padLeft(2, '0')}:'
              '${(safeElapsedSeconds % 60).toString().padLeft(2, '0')}';

    return Card(
      color: AppColors.neutralSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.hero),
        side: const BorderSide(color: AppColors.warningBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: onTap,
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: AppColors.warningContainer,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.warning_amber_rounded,
                      color: AppColors.warningMain,
                    ),
                  ),
                  const SizedBox(width: AppSpace.s2),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(locker.lockerId, style: AppType.subtitle),
                        Text(
                          'Pintu terbuka · ${locker.needsAttentionSinceLabel}',
                          style: AppType.caption.copyWith(
                            color: AppColors.warningText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpace.s2,
                      vertical: AppSpace.s1,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.dangerContainer,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Text(
                      elapsedLabel,
                      style: AppType.bodyStrong.copyWith(
                        color: AppColors.dangerText,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpace.s2),
            Text(
              'Perlu pemeriksaan fisik. Segera cek kondisi pintu.',
              style: AppType.caption.copyWith(color: AppColors.neutralTextBody),
            ),
            const SizedBox(height: AppSpace.s3),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onHandle,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.warningMain,
                  foregroundColor: AppColors.neutralOnInverse,
                ),
                child: const Text('Tangani sekarang'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
