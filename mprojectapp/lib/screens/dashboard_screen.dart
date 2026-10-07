import 'dart:async';
import 'package:flutter/material.dart';
import '../models/locker.dart';
import '../models/session.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/fcm_service.dart';
import '../services/firestore_service.dart'; // ← TAMBAH
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
  final ApiService _api = ApiService();
  final FirestoreService _firestore = FirestoreService(); // ← TAMBAH

  StreamSubscription? _fgMessageSub;
  StreamSubscription? _openedAppSub;

  @override
  void initState() {
    super.initState();

    // HAPUS polling timer — tidak perlu lagi karena Firestore realtime.
    // _pollTimer = Timer.periodic(...)  // ← DIHAPUS

    // Tetap perlu: FCM foreground → tampilkan snackbar.
    // (data lockers sudah auto-update via stream, jadi cukup snackbar-nya)
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
      // Tidak perlu _loadLockers() — Firestore stream sudah handle.
    });

    _openedAppSub = widget.fcmService.onMessageOpenedApp.listen((_) {
      // Tidak perlu apa-apa — stream sudah realtime.
    });
  }

  @override
  void dispose() {
    _fgMessageSub?.cancel();
    _openedAppSub?.cancel();
    super.dispose();
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
      // Tidak perlu refresh — Firestore stream akan push update otomatis.
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
          // Refresh button sekarang opsional — bisa dihilangkan.
          // Tetap dipertahankan sebagai "paksa reload" (jarang dipakai).
          IconButton(
            onPressed: () => setState(() {}),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: StreamBuilder<List<Locker>>(
        stream: _firestore.streamLockers(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return ListView(
              children: [
                const SizedBox(height: 80),
                const Icon(Icons.error_outline, color: Colors.red, size: 40),
                const SizedBox(height: 12),
                Center(child: Text('Gagal memuat data: ${snapshot.error}')),
              ],
            );
          }

          final lockers = snapshot.data ?? [];
          return RefreshIndicator(
            onRefresh: () async {
              // Firestore tidak butuh refresh manual, tapi kita trigger
              // rebuild supaya user dapat feedback visual.
              setState(() {});
            },
            child: _buildBody(lockers),
          );
        },
      ),
    );
  }

  int _countByStatus(List<Locker> lockers, LockerStatus s) =>
      lockers.where((l) => l.status == s).length;

  Widget _buildBody(List<Locker> lockers) {
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
              value: '${_countByStatus(lockers, LockerStatus.empty)}',
              icon: Icons.lock_open,
              color: Colors.green,
            ),
            StatCard(
              label: 'Terisi',
              value: '${_countByStatus(lockers, LockerStatus.occupied)}',
              icon: Icons.lock_outline,
              color: Colors.orange,
            ),
            StatCard(
              label: 'Perlu Perhatian',
              value: '${_countByStatus(lockers, LockerStatus.needsAttention)}',
              icon: Icons.warning_amber_rounded,
              color: Colors.red,
            ),
            StatCard(
              label: 'Total Locker',
              value: '${lockers.length}',
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
        if (lockers.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: Text('Belum ada data locker')),
          )
        else
          ...lockers.map(_buildLockerTile),
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
              ? 'Sejak ${locker.needsAttentionSince}'
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
