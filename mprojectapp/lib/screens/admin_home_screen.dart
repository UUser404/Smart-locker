import 'package:flutter/material.dart';
import '../models/rental_record.dart';
import '../models/session.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/fcm_service.dart';
import '../widgets/dashboard_widgets.dart';
import 'login_screen.dart';

class AdminHomeScreen extends StatefulWidget {
  final AuthSession session;

  const AdminHomeScreen({super.key, required this.session});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  late final ApiService _api;
  late final AuthService _authService;

  RentalStats? _stats;
  List<RentalRecord> _rentals = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _api = ApiService();
    _api.setToken(widget.session.token);
    _authService = AuthService(_api);
    _loadReports();
  }

  Future<void> _loadReports() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final (stats, rentals) = await _api.fetchRentalReports();
      if (!mounted) return;
      setState(() {
        _stats = stats;
        _rentals = rentals;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Gagal memuat laporan: $e';
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

  int get _activeCount => _rentals.where((r) => r.endedAt == null).length;

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
          IconButton(onPressed: _loadReports, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: RefreshIndicator(onRefresh: _loadReports, child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_loading && _rentals.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && _rentals.isEmpty) {
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
      padding: const EdgeInsets.all(16),
      children: [
        ProfileHeader(
          nama: widget.session.nama,
          roleLabel: 'Admin',
          roleColor: Colors.indigo,
          onLogout: _logout,
        ),
        const SizedBox(height: 16),
        if (_stats != null) _buildStatsGrid(_stats!),
        const SizedBox(height: 20),
        const Text(
          'Riwayat Sewa',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        if (_rentals.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: Text('Belum ada riwayat sewa')),
          )
        else
          ..._rentals.map(_buildRentalTile),
      ],
    );
  }

  Widget _buildStatsGrid(RentalStats stats) {
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
          value: '$_activeCount',
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
