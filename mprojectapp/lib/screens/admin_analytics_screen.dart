import 'package:flutter/material.dart';

import '../models/locker.dart';
import '../models/rental_record.dart';
import '../theme/app_theme.dart';
import '../theme/app_tokens.dart';
import '../widgets/design_system_widgets.dart';

class AdminAnalyticsScreen extends StatelessWidget {
  const AdminAnalyticsScreen({
    required this.stats,
    required this.rentals,
    required this.lockers,
    required this.loading,
    required this.error,
    required this.onRefresh,
    this.showLockerListOnly = false,
    super.key,
  });

  final RentalStats? stats;
  final List<RentalRecord> rentals;
  final List<Locker> lockers;
  final bool loading;
  final String? error;
  final Future<void> Function() onRefresh;
  final bool showLockerListOnly;

  int _count(LockerStatus status) =>
      lockers.where((locker) => locker.status == status).length;

  String? _tenantFor(Locker locker) {
    for (final rental in rentals) {
      if (rental.lockerId == locker.lockerId && rental.endedAt == null) {
        return '${rental.nama} · ${rental.noHp}';
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final title = showLockerListOnly ? 'Locker & Perangkat' : 'Ringkasan';
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AppType.title),
            Text(
              'Admin',
              style: AppType.caption.copyWith(
                color: AppColors.neutralTextMuted,
              ),
            ),
          ],
        ),
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
        child: error != null && lockers.isEmpty && rentals.isEmpty
            ? ListView(
                children: [
                  const SizedBox(height: 100),
                  DesignEmptyState(
                    icon: Icons.cloud_off_outlined,
                    title: 'Data tidak dapat dimuat',
                    message: error!,
                  ),
                  Center(
                    child: OutlinedButton.icon(
                      onPressed: onRefresh,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Coba lagi'),
                    ),
                  ),
                ],
              )
            : Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: AppSize.contentMax,
                  ),
                  child: ListView(
                    padding: const EdgeInsets.all(AppSpace.s4),
                    children: showLockerListOnly
                        ? _lockerPage(context)
                        : _summaryPage(context),
                  ),
                ),
              ),
      ),
    );
  }

  List<Widget> _summaryPage(BuildContext context) {
    final activeCount = rentals
        .where((rental) => rental.endedAt == null)
        .length;
    final attentionCount = _count(LockerStatus.needsAttention);

    return [
      if (attentionCount > 0) ...[
        _AttentionBanner(count: attentionCount),
        const SizedBox(height: AppSpace.s4),
      ],
      LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 900 ? 4 : 2;
          final cardHeight = constraints.maxWidth >= 900 ? 104.0 : 88.0;
          return GridView.count(
            crossAxisCount: columns,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: AppSpace.s2,
            crossAxisSpacing: AppSpace.s2,
            mainAxisExtent: cardHeight,
            children: [
              DesignMetricCard(
                label: 'Total sewa',
                value: '${stats?.totalRentals ?? rentals.length}',
                style: AppStatus.info,
              ),
              DesignMetricCard(
                label: 'Rata-rata durasi',
                value: stats?.displayAvgDuration ?? '-',
                style: AppStatus.success,
              ),
              DesignMetricCard(
                label: 'Perhatian',
                value: '$attentionCount',
                style: AppStatus.warning,
                highlighted: attentionCount > 0,
              ),
              DesignMetricCard(
                label: 'Sedang berjalan',
                value: '$activeCount',
                style: AppStatus.info,
              ),
            ],
          );
        },
      ),
      const SizedBox(height: AppSpace.s6),
      const DesignSectionHeader(title: 'Status locker'),
      const SizedBox(height: AppSpace.s2),
      if (lockers.isEmpty && loading)
        const Center(
          child: Padding(
            padding: EdgeInsets.all(AppSpace.s8),
            child: CircularProgressIndicator(),
          ),
        )
      else if (lockers.isEmpty)
        const DesignEmptyState(
          icon: Icons.inventory_2_outlined,
          title: 'Belum ada locker',
          message: 'Data locker akan muncul di sini setelah tersedia.',
        )
      else
        ...lockers.map(
          (locker) => LockerSummaryCard(
            locker: locker,
            tenantName: _tenantFor(locker),
            onTap: () => _showLockerDetails(context, locker),
          ),
        ),
      const SizedBox(height: AppSpace.s4),
      const _DataAvailabilityCard(
        title: 'Aktivitas terbaru',
        message:
            'Log kejadian dan data pemakaian per jam belum disediakan oleh API.',
      ),
    ];
  }

  List<Widget> _lockerPage(BuildContext context) {
    return [
      const _DataAvailabilityCard(
        title: 'Koneksi ESP32',
        message:
            'Endpoint locker saat ini belum mengirim status online atau waktu sinkron terakhir.',
      ),
      const SizedBox(height: AppSpace.s3),
      DesignSectionHeader(title: 'Semua locker (${lockers.length})'),
      const SizedBox(height: AppSpace.s2),
      if (lockers.isEmpty && loading)
        const Center(
          child: Padding(
            padding: EdgeInsets.all(AppSpace.s8),
            child: CircularProgressIndicator(),
          ),
        )
      else if (lockers.isEmpty)
        const DesignEmptyState(
          icon: Icons.inventory_2_outlined,
          title: 'Belum ada data locker',
          message: 'Tarik layar ke bawah untuk memuat ulang.',
        )
      else
        ...lockers.map(
          (locker) => LockerSummaryCard(
            locker: locker,
            tenantName: _tenantFor(locker),
            onTap: () => _showLockerDetails(context, locker),
          ),
        ),
    ];
  }

  void _showLockerDetails(BuildContext context, Locker locker) {
    final style = lockerStatusStyle(locker.status);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.s4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(locker.lockerId, style: AppType.title),
              const SizedBox(height: AppSpace.s2),
              DesignStatusBadge(
                label: lockerStatusLabel(locker.status),
                style: style,
              ),
              const SizedBox(height: AppSpace.s4),
              if (locker.status == LockerStatus.occupied) ...[
                Text(
                  'Durasi sewa · ${locker.displayDuration}',
                  style: AppType.bodyStrong,
                ),
                const SizedBox(height: AppSpace.s2),
                Text(
                  _tenantFor(locker) ?? 'Data penyewa tidak tersedia',
                  style: AppType.bodySm,
                ),
              ] else
                Text(
                  locker.status == LockerStatus.needsAttention
                      ? 'Perhatian sejak ${locker.needsAttentionSinceLabel}'
                      : 'Locker siap disewa.',
                  style: AppType.bodySm,
                ),
              const SizedBox(height: AppSpace.s4),
              const Text(
                'Informasi koneksi perangkat belum tersedia dari API.',
                style: TextStyle(color: AppColors.neutralTextMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AttentionBanner extends StatelessWidget {
  const _AttentionBanner({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpace.s4),
      decoration: BoxDecoration(
        color: AppStatus.warning.tint,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppStatus.warning.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: AppColors.warningMain),
          const SizedBox(width: AppSpace.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$count locker perlu perhatian',
                  style: AppType.bodyStrong,
                ),
                Text(
                  'Periksa status locker dan koordinasikan dengan Petugas.',
                  style: AppType.caption.copyWith(
                    color: AppColors.neutralTextMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DataAvailabilityCard extends StatelessWidget {
  const _DataAvailabilityCard({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.neutralSurfaceMuted,
      child: ListTile(
        leading: const Icon(
          Icons.info_outline,
          color: AppColors.neutralTextMuted,
        ),
        title: Text(title, style: AppType.bodyStrong),
        subtitle: Text(message, style: AppType.caption),
      ),
    );
  }
}
