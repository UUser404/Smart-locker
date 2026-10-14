import 'package:flutter/material.dart';
import '../models/locker.dart';
import '../models/rental_record.dart';
import '../models/session.dart';
import '../widgets/dashboard_widgets.dart';

class AdminAnalyticsScreen extends StatelessWidget {
  final AuthSession session;
  final RentalStats? stats;
  final List<RentalRecord> rentals;
  final List<Locker> lockers;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onLogout;

  const AdminAnalyticsScreen({
    super.key,
    required this.session,
    required this.stats,
    required this.rentals,
    required this.lockers,
    required this.onRefresh,
    required this.onLogout,
  });

  int get _activeCount => rentals.where((r) => r.endedAt == null).length;
  int get _completedCount => rentals.where((r) => r.endedAt != null).length;

  List<MapEntry<String, int>> _topLockers() {
    final freq = <String, int>{};
    for (final r in rentals) {
      freq[r.lockerId] = (freq[r.lockerId] ?? 0) + 1;
    }
    final sorted = freq.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(3).toList();
  }

  // Hitung jumlah locker per status
  int _countLocker(LockerStatus s) =>
      lockers.where((l) => l.status == s).length;

  Color _lockerColor(LockerStatus s) {
    switch (s) {
      case LockerStatus.empty:
        return Colors.green;
      case LockerStatus.occupied:
        return Colors.orange;
      case LockerStatus.needsAttention:
        return Colors.red;
    }
  }

  String _lockerLabel(LockerStatus s) {
    switch (s) {
      case LockerStatus.empty:
        return 'Kosong';
      case LockerStatus.occupied:
        return 'Terisi';
      case LockerStatus.needsAttention:
        return 'Perlu Perhatian';
    }
  }

  IconData _lockerIcon(LockerStatus s) {
    switch (s) {
      case LockerStatus.empty:
        return Icons.lock_open;
      case LockerStatus.occupied:
        return Icons.lock_outline;
      case LockerStatus.needsAttention:
        return Icons.warning_amber_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard Admin'),
        actions: [
          IconButton(
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh),
            tooltip: 'Muat ulang',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ProfileHeader(
              nama: session.nama,
              roleLabel: 'Admin',
              roleColor: Colors.indigo,
              onLogout: onLogout,
            ),
            const SizedBox(height: 20),

            // ============ RINGKASAN STATISTIK ============
            const Text(
              'Ringkasan',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (stats != null) _buildStatsGrid(stats!),

            const SizedBox(height: 24),

            // ============ STATUS LOCKER (BARU) ============
            const Text(
              'Status Locker',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildLockerStatusCard(),

            const SizedBox(height: 24),

            // ============ STATUS SEWA ============
            const Text(
              'Status Sewa',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildRentalStatusCard(),

            const SizedBox(height: 24),

            // ============ TOP LOCKER ============
            const Text(
              'Top Locker',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildTopLockersCard(),
          ],
        ),
      ),
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

  // ============ WIDGET: STATUS LOCKER ============
  Widget _buildLockerStatusCard() {
    if (lockers.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Belum ada data locker',
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Ringkasan count per status
            Row(
              children: [
                Expanded(
                  child: _miniStat(
                    label: 'Kosong',
                    value: _countLocker(LockerStatus.empty),
                    color: Colors.green,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _miniStat(
                    label: 'Terisi',
                    value: _countLocker(LockerStatus.occupied),
                    color: Colors.orange,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _miniStat(
                    label: 'Perhatian',
                    value: _countLocker(LockerStatus.needsAttention),
                    color: Colors.red,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),

            // List setiap locker
            ...lockers.map((locker) => _lockerRow(locker)),
          ],
        ),
      ),
    );
  }

  Widget _miniStat({
    required String label,
    required int value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(
            '$value',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _lockerRow(Locker locker) {
    final color = _lockerColor(locker.status);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(_lockerIcon(locker.status), color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  locker.lockerId,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                if (locker.status == LockerStatus.occupied)
                  Text(
                    'Durasi: ${locker.displayDuration}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  )
                else if (locker.status == LockerStatus.needsAttention)
                  Text(
                    'Sejak ${locker.needsAttentionSinceLabel}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  )
                else
                  Text(
                    'Siap disewa',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _lockerLabel(locker.status),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRentalStatusCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _statusRow(
              'Aktif',
              '$_activeCount',
              Icons.lock_open,
              Colors.orange,
            ),
            const Divider(height: 20),
            _statusRow(
              'Selesai',
              '$_completedCount',
              Icons.check_circle_outline,
              Colors.green,
            ),
            const Divider(height: 20),
            _statusRow(
              'Total',
              '${rentals.length}',
              Icons.receipt_long,
              Colors.grey,
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusRow(String label, String value, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: color,
            fontSize: 16,
          ),
        ),
      ],
    );
  }

  Widget _buildTopLockersCard() {
    final top = _topLockers();
    if (top.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Belum ada data',
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: [
            for (var i = 0; i < top.length; i++)
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.indigo.shade100,
                  child: Text(
                    '${i + 1}',
                    style: TextStyle(
                      color: Colors.indigo.shade800,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                title: Text(top[i].key),
                trailing: Text(
                  '${top[i].value}x',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
