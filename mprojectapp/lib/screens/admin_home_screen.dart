import 'package:flutter/material.dart';
import '../models/rental_record.dart';
import '../models/session.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/fcm_service.dart';
import '../services/firestore_service.dart'; // ← TAMBAH
import '../widgets/dashboard_widgets.dart';
import 'login_screen.dart';

class AdminHomeScreen extends StatefulWidget {
  final AuthSession session;

  const AdminHomeScreen({super.key, required this.session});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  final FirestoreService _firestore = FirestoreService(); // ← TAMBAH

  // Hapus: _stats, _rentals, _loading, _error, _loadReports()
  // Semua di-handle oleh StreamBuilder + computeStats

  Future<void> _logout() async {
    final api = ApiService();
    await AuthService(api).logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => LoginScreen(
          authService: AuthService(api),
          fcmService: FcmService(api),
        ),
      ),
      (route) => false,
    );
  }

  int _activeCount(List<RentalRecord> rentals) =>
      rentals.where((r) => r.endedAt == null).length;

  String _formatDateTime(DateTime dt) {
    final local = dt.toLocal();
    final d = local.day.toString().padLeft(2, '0');
    final m = local.month.toString().padLeft(2, '0');
    final h = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    return '$d/$m $h:$min';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard Admin'),
        actions: [
          IconButton(
            onPressed: () => setState(() {}), // paksa rebuild (opsional)
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: StreamBuilder<List<RentalRecord>>(
        stream: _firestore.streamRentals(limit: 200),
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
                Center(child: Text('Gagal memuat laporan: ${snapshot.error}')),
              ],
            );
          }

          final rentals = snapshot.data ?? [];
          final stats = _firestore.computeStats(rentals);

          return RefreshIndicator(
            onRefresh: () async => setState(() {}),
            child: _buildBody(rentals, stats),
          );
        },
      ),
    );
  }

  Widget _buildBody(List<RentalRecord> rentals, RentalStats stats) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ProfileHeader(
          nama: widget.session.nama,
          roleLabel: 'Admin',
          roleColor: Colors.indigo,
          onLogout: _logout,
        ),
        const SizedBox(height: 16),
        _buildStatsGrid(stats, rentals),
        const SizedBox(height: 20),
        const Text(
          'Riwayat Sewa',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        if (rentals.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: Text('Belum ada riwayat sewa')),
          )
        else
          ...rentals.map(_buildRentalTile),
      ],
    );
  }

  Widget _buildStatsGrid(RentalStats stats, List<RentalRecord> rentals) {
    return StatGrid(
      cards: [
        StatCard(
          label: 'Total Sewa',
          value: '${stats.totalRentals}',
          icon: Icons.receipt_long,
          color: Colors.indigo,
        ),
        StatCard(
          label: 'Sedang Aktif',
          value: '${_activeCount(rentals)}',
          icon: Icons.lock_open,
          color: Colors.orange,
        ),
        StatCard(
          label: 'Rata-rata Durasi',
          value: stats.displayAvgDuration,
          icon: Icons.timer_outlined,
          color: Colors.teal,
        ),
        StatCard(
          label: 'Paling Sering',
          value: stats.busiestLockerId ?? '-',
          icon: Icons.trending_up,
          color: Colors.purple,
        ),
      ],
    );
  }

  Widget _buildRentalTile(RentalRecord r) {
    final isActive = r.endedAt == null;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isActive
              ? Colors.orange.shade100
              : Colors.grey.shade200,
          child: Icon(
            isActive ? Icons.lock_open : Icons.lock_outline,
            color: isActive ? Colors.orange.shade800 : Colors.black54,
            size: 20,
          ),
        ),
        title: Row(
          children: [
            Expanded(child: Text('${r.lockerId} — ${r.nama}')),
            StatusBadge(
              text: isActive ? 'Aktif' : 'Selesai',
              color: isActive ? Colors.orange : Colors.green,
            ),
          ],
        ),
        subtitle: Text(
          isActive
              ? 'Mulai ${_formatDateTime(r.startedAt)} · masih berjalan'
              : '${_formatDateTime(r.startedAt)} - ${_formatDateTime(r.endedAt!)} · ${r.displayDuration}',
        ),
        trailing: Text(r.noHp, style: const TextStyle(fontSize: 12)),
      ),
    );
  }
}
