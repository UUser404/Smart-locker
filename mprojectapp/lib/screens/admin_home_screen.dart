import 'package:flutter/material.dart';
import '../models/rental_record.dart';
import '../models/session.dart';
import '../services/api_service.dart';

class AdminHomeScreen extends StatefulWidget {
  final AuthSession session;

  const AdminHomeScreen({super.key, required this.session});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  final ApiService _api = ApiService();

  RentalStats? _stats;
  List<RentalRecord> _rentals = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
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
        title: Text('Laporan — ${widget.session.nama}'),
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
        if (_stats != null) _buildStatsRow(_stats!),
        const SizedBox(height: 20),
        const Text(
          'Riwayat Sewa',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ..._rentals.map(_buildRentalTile),
      ],
    );
  }

  Widget _buildStatsRow(RentalStats stats) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(label: 'Total Sewa', value: '${stats.totalRentals}'),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            label: 'Rata-rata Durasi',
            value: stats.displayAvgDuration,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            label: 'Paling Sering',
            value: stats.busiestLockerId ?? '-',
          ),
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
          backgroundColor: isActive ? Colors.orange : Colors.grey.shade300,
          child: Icon(
            isActive ? Icons.lock_open : Icons.lock_outline,
            color: isActive ? Colors.white : Colors.black54,
            size: 20,
          ),
        ),
        title: Text('${r.lockerId} — ${r.nama}'),
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

class _StatCard extends StatelessWidget {
  final String label;
  final String value;

  const _StatCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(fontSize: 11, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
