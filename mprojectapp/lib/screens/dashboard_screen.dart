import 'dart:async';
import 'package:flutter/material.dart';
import '../models/locker.dart';
import '../models/session.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/fcm_service.dart';
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
  final ApiService _api = ApiService();

  List<Locker> _lockers = [];
  bool _loading = true;
  String? _error;
  Timer? _pollTimer;
  StreamSubscription? _fgMessageSub;
  StreamSubscription? _openedAppSub;

  @override
  void initState() {
    super.initState();
    _loadLockers();

    // Refresh berkala supaya durasi occupied ikut jalan tanpa perlu
    // menunggu push notification.
    _pollTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _loadLockers(silent: true);
    });

    // Locker jadi needs_attention -> backend kirim push -> langsung refresh
    // + tampilkan snackbar walau app sedang dibuka (foreground).
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

    // User tap notifikasi dari background -> pastikan dashboard ter-refresh.
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
    await AuthService(ApiService()).logout();
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
      case LockerStatus.unknown:
        return Colors.grey;
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
      case LockerStatus.unknown:
        return 'Tidak diketahui';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Status Locker — ${widget.session.nama}'),
        actions: [
          IconButton(
            onPressed: () => _loadLockers(),
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            onPressed: _logout,
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
          ),
        ],
      ),
      body: RefreshIndicator(onRefresh: _loadLockers, child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_loading && _lockers.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && _lockers.isEmpty) {
      return ListView(
        // ListView supaya pull-to-refresh tetap jalan walau isinya cuma error
        children: [
          const SizedBox(height: 80),
          Icon(Icons.error_outline, color: Colors.red, size: 40),
          const SizedBox(height: 12),
          Center(child: Text(_error!)),
        ],
      );
    }

    if (_lockers.isEmpty) {
      return const Center(child: Text('Belum ada data locker'));
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: _lockers.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final locker = _lockers[index];
        return Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: _statusColor(locker.status),
              child: Text(
                locker.lockerId.replaceAll(RegExp(r'[^0-9]'), ''),
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
            title: Text(locker.lockerId),
            subtitle: Text(
              locker.status == LockerStatus.occupied
                  ? '${_statusLabel(locker.status)} · ${locker.displayDuration}'
                  : locker.status == LockerStatus.needsAttention
                  ? '${_statusLabel(locker.status)} · sejak ${locker.needsAttentionSince}'
                  : _statusLabel(locker.status),
            ),
            trailing: locker.status == LockerStatus.needsAttention
                ? FilledButton.tonal(
                    onPressed: () => _resolveLocker(locker),
                    child: const Text('Resolve'),
                  )
                : null,
          ),
        );
      },
    );
  }
}
