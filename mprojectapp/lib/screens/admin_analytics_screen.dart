import 'package:flutter/material.dart';

import '../models/controller_status.dart';
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
    this.deviceStatuses = const [],
    this.deviceError,
    required this.loading,
    required this.error,
    required this.onRefresh,
    this.showLockerListOnly = false,
    super.key,
  });

  final RentalStats? stats;
  final List<RentalRecord> rentals;
  final List<Locker> lockers;
  final List<ControllerStatus> deviceStatuses;
  final String? deviceError;
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

  ControllerStatus? _deviceStatusFor(Locker locker) {
    for (final device in deviceStatuses) {
      if (device.controllerId == locker.controllerId) return device;
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
              'Admin · ${lockers.length} locker',
              style: AppType.caption.copyWith(
                color: AppColors.neutralTextMuted,
              ),
            ),
          ],
        ),
        actions: [
          if (!showLockerListOnly && MediaQuery.sizeOf(context).width >= 768)
            Padding(
              padding: const EdgeInsets.only(right: AppSpace.s2),
              child: Center(
                child: Text(
                  deviceStatuses.isEmpty
                      ? 'ESP32 belum terdaftar'
                      : '${deviceStatuses.where((device) => device.online).length}'
                            '/${deviceStatuses.length} ESP32 online',
                  style: AppType.caption.copyWith(
                    color: AppColors.neutralTextMuted,
                  ),
                ),
              ),
            ),
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
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final useWebLayout = constraints.maxWidth >= 768;
                      return ListView(
                        padding: const EdgeInsets.all(AppSpace.s4),
                        children: showLockerListOnly
                            ? _lockerPage(context)
                            : useWebLayout
                            ? _webSummaryPage(context)
                            : _summaryPage(context),
                      );
                    },
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
    final attentionLockers = lockers
        .where((locker) => locker.status == LockerStatus.needsAttention)
        .toList();
    final attentionLocker = attentionLockers.isEmpty
        ? null
        : attentionLockers.first;

    return [
      ControllerStatusCard(
        devices: deviceStatuses,
        loading: loading,
        error: deviceError,
      ),
      const SizedBox(height: AppSpace.s4),
      if (attentionLocker != null) ...[
        _AttentionBanner(
          count: attentionLockers.length,
          locker: attentionLocker,
          onTap: () => _showLockerDetails(context, attentionLocker),
          expanded: false,
        ),
        const SizedBox(height: AppSpace.s4),
      ],
      _metricsGrid(context, columns: 2),
      const SizedBox(height: AppSpace.s6),
      DesignSectionHeader(
        title: 'Status locker',
        trailing: DesignStatusBadge(
          label: '$activeCount sesi aktif',
          style: AppStatus.info,
        ),
      ),
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
            deviceStatus: _deviceStatusFor(locker),
            onTap: () => _showLockerDetails(context, locker),
          ),
        ),
      const SizedBox(height: AppSpace.s4),
      const _DataAvailabilityCard(
        title: 'Aktivitas terbaru',
        message: 'Log kejadian belum disediakan oleh API.',
      ),
    ];
  }

  List<Widget> _webSummaryPage(BuildContext context) {
    final attentionLockers = lockers
        .where((locker) => locker.status == LockerStatus.needsAttention)
        .toList();
    final attentionLocker = attentionLockers.isEmpty
        ? null
        : attentionLockers.first;

    return [
      ControllerStatusCard(
        devices: deviceStatuses,
        loading: loading,
        error: deviceError,
      ),
      const SizedBox(height: AppSpace.s4),
      if (attentionLocker != null) ...[
        _AttentionBanner(
          count: attentionLockers.length,
          locker: attentionLocker,
          onTap: () => _showLockerDetails(context, attentionLocker),
          expanded: true,
        ),
        const SizedBox(height: AppSpace.s4),
      ],
      _metricsGrid(context, columns: 4),
      const SizedBox(height: AppSpace.s6),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 7,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DesignSectionHeader(
                  title: 'Status locker',
                  trailing: DesignStatusBadge(
                    label:
                        '${rentals.where((rental) => rental.endedAt == null).length} sesi aktif',
                    style: AppStatus.info,
                  ),
                ),
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
                    message:
                        'Data locker akan muncul di sini setelah tersedia.',
                  )
                else
                  GridView.builder(
                    itemCount: lockers.length,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisExtent: 220,
                          crossAxisSpacing: AppSpace.s2,
                          mainAxisSpacing: AppSpace.s2,
                        ),
                    itemBuilder: (context, index) {
                      final locker = lockers[index];
                      return _AdminWebLockerCard(
                        locker: locker,
                        tenantName: _tenantFor(locker),
                        onTap: () => _showLockerDetails(context, locker),
                      );
                    },
                  ),
                const SizedBox(height: AppSpace.s4),
                const _UsageUnavailableCard(),
              ],
            ),
          ),
          const SizedBox(width: AppSpace.s4),
          const Expanded(flex: 5, child: _EventsUnavailablePanel()),
        ],
      ),
    ];
  }

  Widget _metricsGrid(BuildContext context, {required int columns}) {
    final attentionCount = _count(LockerStatus.needsAttention);
    final now = DateTime.now();
    final todayRentalCount = rentals.where((rental) {
      final startedAt = rental.startedAt.toLocal();
      return startedAt.year == now.year &&
          startedAt.month == now.month &&
          startedAt.day == now.day;
    }).length;

    return GridView(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        mainAxisExtent: 120 * MediaQuery.textScalerOf(context).scale(1),
        mainAxisSpacing: AppSpace.s2,
        crossAxisSpacing: AppSpace.s2,
      ),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        DesignMetricCard(
          label: 'Sewa hari ini',
          value: loading && rentals.isEmpty ? '—' : '$todayRentalCount',
          style: AppStatus.info,
          valueColor: AppColors.neutralInk,
          supportingText: 'Sesi dimulai hari ini',
        ),
        DesignMetricCard(
          label: 'Rata-rata durasi',
          value: stats?.displayAvgDuration ?? '-',
          style: AppStatus.success,
          valueColor: AppColors.neutralInk,
          supportingText: '${stats?.totalRentals ?? rentals.length} sesi',
        ),
        DesignMetricCard(
          label: 'Perhatian',
          value: '$attentionCount',
          style: AppStatus.warning,
          highlighted: attentionCount > 0,
          supportingText: 'Locker perlu diperiksa',
        ),
        DesignMetricCard(
          label: 'Buka darurat',
          value: '—',
          style: AppStatus.danger,
          valueColor: AppColors.dangerMain,
          supportingText: 'Log audit belum tersedia',
        ),
      ],
    );
  }

  List<Widget> _lockerPage(BuildContext context) {
    return [
      ControllerStatusCard(
        devices: deviceStatuses,
        loading: loading,
        error: deviceError,
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
            deviceStatus: _deviceStatusFor(locker),
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
              Text(
                locker.controllerId == null
                    ? 'ESP32 belum terdaftar untuk locker ini.'
                    : 'ESP32 ${_deviceStatusFor(locker)?.online == true ? 'online' : 'offline'}'
                          ' · ${_deviceStatusFor(locker)?.lastSeenAt == null ? 'belum pernah tersambung' : 'sinkron terakhir ${_deviceStatusFor(locker)!.lastSeenAt!.toLocal()}'}',
                style: const TextStyle(color: AppColors.neutralTextMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AttentionBanner extends StatelessWidget {
  const _AttentionBanner({
    required this.count,
    required this.locker,
    required this.onTap,
    required this.expanded,
  });

  final int count;
  final Locker locker;
  final VoidCallback onTap;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppStatus.warning.tint,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppStatus.warning.border),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.s4),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: AppColors.warningContainer,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: AppColors.warningMain,
                ),
              ),
              const SizedBox(width: AppSpace.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${locker.lockerId} · pintu terbuka ${locker.displayDuration}',
                      style: AppType.bodyStrong,
                    ),
                    Text(
                      '$count locker perlu perhatian · status ESP32 belum tersedia dari API',
                      style: AppType.caption.copyWith(
                        color: AppColors.neutralTextMuted,
                      ),
                    ),
                  ],
                ),
              ),
              if (expanded) ...[
                const SizedBox(width: AppSpace.s3),
                FilledButton(
                  onPressed: onTap,
                  child: const Text('Lihat detail'),
                ),
              ] else
                const Icon(
                  Icons.chevron_right,
                  color: AppColors.neutralTextMuted,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminWebLockerCard extends StatelessWidget {
  const _AdminWebLockerCard({
    required this.locker,
    required this.tenantName,
    required this.onTap,
  });

  final Locker locker;
  final String? tenantName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final style = lockerStatusStyle(locker.status);
    final attention = locker.status == LockerStatus.needsAttention;
    final occupied = locker.status == LockerStatus.occupied;
    final number = locker.lockerId.replaceAll(RegExp(r'[^0-9]'), '');
    final metric = occupied
        ? locker.displayDuration
        : attention
        ? locker.displayDuration
        : 'Siap';

    return Card(
      color: attention ? style.tint : AppColors.neutralSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        side: BorderSide(
          color: attention ? style.border : AppColors.neutralBorder,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.s4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: style.container,
                    child: Text(
                      number,
                      style: AppType.bodyStrong.copyWith(color: style.main),
                    ),
                  ),
                  const SizedBox(width: AppSpace.s2),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(locker.lockerId, style: AppType.bodyStrong),
                        Text(
                          occupied
                              ? tenantName ?? 'Penyewa tidak tersedia'
                              : attention
                              ? 'Tidak ada penyewa aktif'
                              : 'Siap disewa',
                          style: AppType.caption.copyWith(
                            color: AppColors.neutralTextMuted,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpace.s1),
                  DesignStatusBadge(
                    label: lockerStatusLabel(locker.status),
                    style: style,
                  ),
                ],
              ),
              const SizedBox(height: AppSpace.s3),
              Text(
                metric,
                style: AppType.headline.copyWith(
                  color: attention
                      ? AppColors.dangerMain
                      : occupied
                      ? AppColors.infoMain
                      : AppColors.successMain,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                attention
                    ? 'pintu terbuka'
                    : occupied
                    ? 'durasi sewa'
                    : 'status locker',
                style: AppType.caption.copyWith(
                  color: AppColors.neutralTextMuted,
                ),
              ),
              const Spacer(),
              const Divider(height: AppSpace.s3),
              Row(
                children: [
                  const Icon(
                    Icons.sensors_outlined,
                    size: 14,
                    color: AppColors.neutralTextMuted,
                  ),
                  const SizedBox(width: AppSpace.s1),
                  Expanded(
                    child: Text(
                      'Status ESP32 belum tersedia',
                      style: AppType.micro.copyWith(
                        color: AppColors.neutralTextMuted,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  TextButton(
                    onPressed: onTap,
                    style: TextButton.styleFrom(
                      minimumSize: const Size(44, AppSize.touchMin),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpace.s2,
                      ),
                    ),
                    child: const Text('Detail'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EventsUnavailablePanel extends StatelessWidget {
  const _EventsUnavailablePanel();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const DesignSectionHeader(title: 'Kejadian terbaru'),
        const SizedBox(height: AppSpace.s2),
        Card(
          child: SizedBox(
            height: 414,
            width: double.infinity,
            child: Padding(
              padding: const EdgeInsets.all(AppSpace.s4),
              child: const DesignEmptyState(
                icon: Icons.event_note_outlined,
                title: 'Log kejadian belum tersedia',
                message:
                    'Server belum menyediakan endpoint aktivitas dan audit. Data contoh tidak ditampilkan.',
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _UsageUnavailableCard extends StatelessWidget {
  const _UsageUnavailableCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Pemakaian per jam', style: AppType.subtitle),
                ),
                Text(
                  '7 hari terakhir',
                  style: AppType.caption.copyWith(
                    color: AppColors.neutralTextMuted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpace.s4),
            SizedBox(
              height: 200,
              child: DesignEmptyState(
                icon: Icons.bar_chart_outlined,
                title: 'Grafik belum tersedia',
                message:
                    'API belum menyediakan agregasi sewa per jam atau per hari.',
              ),
            ),
          ],
        ),
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
