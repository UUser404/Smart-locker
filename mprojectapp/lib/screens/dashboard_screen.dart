import 'dart:async';
import 'package:flutter/material.dart';
import '../models/locker.dart';
import '../models/session.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/fcm_service.dart';
import '../widgets/dashboard_widgets.dart';
import 'login_screen.dart';

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

class _DashboardScreenState extends State<DashboardScreen> {
  late final ApiService _api;
  late final AuthService _authService;

  List<Locker> _lockers = [];
  bool _loading = true;
  String? _error;
  Timer? _pollTimer;
  StreamSubscription? _fgMessageSub;
  StreamSubscription? _openedAppSub;

  @override
  void initState() {
    super.initState();

    _api = ApiService();
    _api.setToken(widget.session.token);
    _authService = AuthService(_api);

    _loadLockers();

    // Polling 10 detik karena Express tidak realtime (bukan Firestore stream)
    _pollTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _loadLockers(silent: true);
    });

    _fgMessageSub = widget.fcmService.onForegroundMessage.listen((message) {
      final lockerId = message.data['locker_id'];
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              message.notification?.body ?? 'Locker $lockerId perlu perhatian',
            ),
          ),
        );
      }
      _loadLockers(silent: true);
    });

    _openedAppSub = widget.fcmService.onMessageOpenedApp.listen((_) {
      _loadLockers(silent: true);
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _fgMessageSub?.cancel();
    _openedAppSub?.cancel();
    super.dispose();
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
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (!silent) _error = 'Gagal memuat data: $e';
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
          fcmService: widget.fcmService,
        ),
      ),
      (route) => false,
    );
  }

  Future<void> _resolveLocker(Locker locker) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Selesaikan Locker?'),
        content: Text(
          'Pastikan kamu sudah mengecek dan menutup fisik ${locker.lockerId} '
          'sebelum menandainya kosong kembali.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Ya, Selesaikan'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _api.resolveLocker(locker.lockerId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${locker.lockerId} ditandai kosong')),
      );
      _loadLockers(silent: true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal resolve: $e')));
    }
  }

  Color _statusColor(LockerStatus status) {
    switch (status) {
      case LockerStatus.empty:
        return Colors.green;
      case LockerStatus.occupied:
        return Colors.orange;
      case LockerStatus.needsAttention:
        return Colors.red;
    }
  }

  String _statusLabel(LockerStatus status) {
    switch (status) {
      case LockerStatus.empty:
        return 'Kosong';
      case LockerStatus.occupied:
        return 'Terisi';
      case LockerStatus.needsAttention:
        return 'Perlu Perhatian';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard Petugas'),
        actions: [
          IconButton(
            onPressed: () => _loadLockers(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(onRefresh: _loadLockers, child: _buildBody()),
    );
  }

  int _countByStatus(LockerStatus s) =>
      _lockers.where((l) => l.status == s).length;

  Widget _buildBody() {
    if (_loading && _lockers.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && _lockers.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 80),
          const Icon(Icons.error_outline, color: Colors.red, size: 40),
          const SizedBox(height: 12),
          Center(child: Text(_error!)),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        ProfileHeader(
          nama: widget.session.nama,
          roleLabel: 'Petugas Keamanan',
          roleColor: Colors.teal,
          onLogout: _logout,
        ),
        const SizedBox(height: 16),
        StatGrid(
          cards: [
            StatCard(
              label: 'Kosong',
              value: '${_countByStatus(LockerStatus.empty)}',
              icon: Icons.lock_open,
              color: Colors.green,
            ),
            StatCard(
              label: 'Terisi',
              value: '${_countByStatus(LockerStatus.occupied)}',
              icon: Icons.lock_outline,
              color: Colors.orange,
            ),
            StatCard(
              label: 'Perlu Perhatian',
              value: '${_countByStatus(LockerStatus.needsAttention)}',
              icon: Icons.warning_amber_rounded,
              color: Colors.red,
            ),
            StatCard(
              label: 'Total Locker',
              value: '${_lockers.length}',
              icon: Icons.grid_view_rounded,
              color: Colors.indigo,
            ),
          ],
        ),
        const SizedBox(height: 20),
        const Text(
          'Status Locker',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        if (_lockers.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: Text('Belum ada data locker')),
          )
        else
          ..._lockers.map(_buildLockerTile),
      ],
    );
  }

  Widget _buildLockerTile(Locker locker) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _statusColor(locker.status).withValues(alpha: 0.15),
          child: Text(
            locker.lockerId.replaceAll(RegExp(r'[^0-9]'), ''),
            style: TextStyle(
              color: _statusColor(locker.status),
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ),
        title: Row(
          children: [
            Expanded(child: Text(locker.lockerId)),
            StatusBadge(
              text: _statusLabel(locker.status),
              color: _statusColor(locker.status),
            ),
          ],
        ),
        subtitle: Text(
          locker.status == LockerStatus.occupied
              ? 'Durasi berjalan: ${locker.displayDuration}'
              : locker.status == LockerStatus.needsAttention
              ? 'Sejak ${locker.needsAttentionSinceLabel}'
              : 'Siap disewa',
        ),
        trailing: locker.status == LockerStatus.needsAttention
            ? FilledButton.tonal(
                onPressed: () => _resolveLocker(locker),
                child: const Text('Resolve'),
              )
            : null,
      ),
    );
  }
}
