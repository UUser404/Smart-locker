import 'package:flutter/material.dart';

import '../models/audit_log_record.dart';
import '../theme/app_theme.dart';
import '../theme/app_tokens.dart';
import 'design_system_widgets.dart';

enum _AuditFilter { all, emergency, resolve }

class AuditLogFeed extends StatefulWidget {
  const AuditLogFeed({
    required this.logs,
    required this.loading,
    required this.onRefresh,
    this.error,
    this.showActor = true,
    super.key,
  });

  final List<AuditLogRecord> logs;
  final bool loading;
  final String? error;
  final Future<void> Function() onRefresh;
  final bool showActor;

  @override
  State<AuditLogFeed> createState() => _AuditLogFeedState();
}

class _AuditLogFeedState extends State<AuditLogFeed> {
  _AuditFilter _filter = _AuditFilter.all;

  List<AuditLogRecord> get _filteredLogs => widget.logs.where((log) {
    return switch (_filter) {
      _AuditFilter.all => true,
      _AuditFilter.emergency => log.action == 'emergency_open',
      _AuditFilter.resolve => log.action == 'locker_resolved',
    };
  }).toList();

  @override
  Widget build(BuildContext context) {
    final logs = _filteredLogs;
    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      child: ListView(
        padding: const EdgeInsets.all(AppSpace.s4),
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _filterChip('Semua', _AuditFilter.all),
                _filterChip('Darurat', _AuditFilter.emergency),
                _filterChip('Resolve', _AuditFilter.resolve),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.s3),
          if (widget.error != null)
            DesignEmptyState(
              icon: Icons.cloud_off_outlined,
              title: 'Riwayat tidak dapat dimuat',
              message: widget.error!,
            )
          else if (widget.loading && logs.isEmpty)
            const Padding(
              padding: EdgeInsets.all(AppSpace.s8),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (logs.isEmpty)
            const DesignEmptyState(
              icon: Icons.event_note_outlined,
              title: 'Belum ada riwayat',
              message: 'Tindakan yang tercatat akan muncul di sini.',
            )
          else
            ...logs.map(_buildLogCard),
        ],
      ),
    );
  }

  Widget _filterChip(String label, _AuditFilter filter) {
    final selected = _filter == filter;
    return Padding(
      padding: const EdgeInsets.only(right: AppSpace.s2),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => setState(() => _filter = filter),
        selectedColor: AppColors.neutralInk,
        labelStyle: TextStyle(
          color: selected
              ? AppColors.neutralOnInverse
              : AppColors.neutralTextBody,
        ),
      ),
    );
  }

  Widget _buildLogCard(AuditLogRecord log) {
    final isEmergency = log.action == 'emergency_open';
    final style = isEmergency ? AppStatus.danger : AppStatus.success;
    final details = <String>[
      if (log.lockerId != null) log.lockerId!,
      if (log.reason != null) log.reason!,
      if (log.endSession == true) 'Sesi diakhiri',
    ];

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpace.s2),
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(log.title, style: AppType.bodyStrong)),
                DesignStatusBadge(
                  label: isEmergency ? 'Darurat' : 'Selesai',
                  style: style,
                ),
              ],
            ),
            if (details.isNotEmpty) ...[
              const SizedBox(height: AppSpace.s1),
              Text(details.join(' · '), style: AppType.bodySm),
            ],
            if (widget.showActor &&
                (log.actorName ?? log.actorUsername) != null)
              Padding(
                padding: const EdgeInsets.only(top: AppSpace.s1),
                child: Text(
                  'Petugas: ${log.actorName ?? log.actorUsername}'
                  '${log.actorRole == null ? '' : ' · ${log.actorRole}'}',
                  style: AppType.caption.copyWith(
                    color: AppColors.neutralTextMuted,
                  ),
                ),
              ),
            const SizedBox(height: AppSpace.s1),
            Text(
              _formatDateTime(log.occurredAt),
              style: AppType.caption.copyWith(
                color: AppColors.neutralTextMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime? value) {
    if (value == null) return 'Waktu tidak tersedia';
    final local = value.toLocal();
    final date =
        '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')}/${local.year}';
    final time =
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
    return '$date $time';
  }
}
