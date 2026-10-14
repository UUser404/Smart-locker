import 'package:flutter/material.dart';
import '../models/rental_record.dart';
import '../models/session.dart';
import '../widgets/dashboard_widgets.dart';

enum _HistoryFilter { all, active, completed }

class AdminHistoryScreen extends StatefulWidget {
  final AuthSession session;
  final List<RentalRecord> rentals;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onLogout;

  const AdminHistoryScreen({
    super.key,
    required this.session,
    required this.rentals,
    required this.onRefresh,
    required this.onLogout,
  });

  @override
  State<AdminHistoryScreen> createState() => _AdminHistoryScreenState();
}

class _AdminHistoryScreenState extends State<AdminHistoryScreen> {
  _HistoryFilter _filter = _HistoryFilter.all;

  List<RentalRecord> get _filtered {
    switch (_filter) {
      case _HistoryFilter.all:
        return widget.rentals;
      case _HistoryFilter.active:
        return widget.rentals.where((r) => r.endedAt == null).toList();
      case _HistoryFilter.completed:
        return widget.rentals.where((r) => r.endedAt != null).toList();
    }
  }

  int get _activeCount => widget.rentals.where((r) => r.endedAt == null).length;
  int get _completedCount =>
      widget.rentals.where((r) => r.endedAt != null).length;

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
    final filtered = _filtered;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Riwayat Sewa'),
        actions: [
          IconButton(
            onPressed: widget.onRefresh,
            icon: const Icon(Icons.refresh),
            tooltip: 'Muat ulang',
          ),
        ],
      ),
      body: Column(
        children: [
          // === FILTER CHIPS ===
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _chip(
                  label: 'Semua',
                  count: widget.rentals.length,
                  value: _HistoryFilter.all,
                ),
                const SizedBox(width: 8),
                _chip(
                  label: 'Aktif',
                  count: _activeCount,
                  value: _HistoryFilter.active,
                ),
                const SizedBox(width: 8),
                _chip(
                  label: 'Selesai',
                  count: _completedCount,
                  value: _HistoryFilter.completed,
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // === LIST RIWAYAT ===
          Expanded(
            child: RefreshIndicator(
              onRefresh: widget.onRefresh,
              child: filtered.isEmpty
                  ? ListView(
                      children: [
                        const SizedBox(height: 80),
                        Icon(
                          Icons.receipt_long_outlined,
                          size: 48,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 12),
                        Center(
                          child: Text(
                            'Belum ada riwayat ${_filterLabel()}',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      itemCount: filtered.length,
                      itemBuilder: (context, i) =>
                          _buildRentalTile(filtered[i]),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  String _filterLabel() {
    switch (_filter) {
      case _HistoryFilter.all:
        return '';
      case _HistoryFilter.active:
        return 'aktif';
      case _HistoryFilter.completed:
        return 'selesai';
    }
  }

  Widget _chip({
    required String label,
    required int count,
    required _HistoryFilter value,
  }) {
    final selected = _filter == value;
    return ChoiceChip(
      label: Text('$label ($count)'),
      selected: selected,
      onSelected: (_) => setState(() => _filter = value),
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
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isActive
                    ? 'Mulai ${_formatDateTime(r.startedAt)} · masih berjalan'
                    : '${_formatDateTime(r.startedAt)} - ${_formatDateTime(r.endedAt!)} · ${r.displayDuration}',
              ),
              const SizedBox(height: 2),
              Text(
                r.noHp,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
