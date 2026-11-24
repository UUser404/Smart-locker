import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/rental_record.dart';
import '../theme/app_theme.dart';
import '../theme/app_tokens.dart';
import '../widgets/design_system_widgets.dart';

enum _RentalStatusFilter { all, active, completed }

class AdminHistoryScreen extends StatefulWidget {
  const AdminHistoryScreen({
    required this.rentals,
    required this.onRefresh,
    super.key,
  });

  final List<RentalRecord> rentals;
  final Future<void> Function() onRefresh;

  @override
  State<AdminHistoryScreen> createState() => _AdminHistoryScreenState();
}

class _AdminHistoryScreenState extends State<AdminHistoryScreen> {
  final _searchController = TextEditingController();
  _RentalStatusFilter _statusFilter = _RentalStatusFilter.all;
  String _lockerFilter = 'Semua locker';
  bool _todayOnly = true;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<String> get _lockerOptions {
    final options =
        widget.rentals.map((rental) => rental.lockerId).toSet().toList()
          ..sort();
    return ['Semua locker', ...options];
  }

  String get _effectiveLockerFilter =>
      _lockerOptions.contains(_lockerFilter) ? _lockerFilter : 'Semua locker';

  List<RentalRecord> get _filteredRentals {
    final query = _searchController.text.trim().toLowerCase();
    final now = DateTime.now();
    return widget.rentals.where((rental) {
      final matchesStatus = switch (_statusFilter) {
        _RentalStatusFilter.all => true,
        _RentalStatusFilter.active => rental.endedAt == null,
        _RentalStatusFilter.completed => rental.endedAt != null,
      };
      final matchesLocker =
          _effectiveLockerFilter == 'Semua locker' ||
          rental.lockerId == _effectiveLockerFilter;
      final matchesToday =
          !_todayOnly ||
          (rental.startedAt.year == now.year &&
              rental.startedAt.month == now.month &&
              rental.startedAt.day == now.day);
      final matchesQuery =
          query.isEmpty ||
          rental.nama.toLowerCase().contains(query) ||
          rental.noHp.toLowerCase().contains(query) ||
          rental.rentalId.toLowerCase().contains(query);
      return matchesStatus && matchesLocker && matchesToday && matchesQuery;
    }).toList();
  }

  Future<void> _copyCsv() async {
    final records = _filteredRentals;
    final rows = <List<String>>[
      [
        'ID Sesi',
        'Locker',
        'Penyewa',
        'Telepon',
        'Mulai',
        'Selesai',
        'Durasi',
        'Status',
      ],
      ...records.map(
        (rental) => [
          rental.rentalId,
          rental.lockerId,
          rental.nama,
          rental.noHp,
          rental.startedAt.toIso8601String(),
          rental.endedAt?.toIso8601String() ?? '',
          rental.displayDuration,
          rental.endedAt == null ? 'Berjalan' : 'Selesai',
        ],
      ),
    ];
    final csv = rows.map((row) => row.map(_escapeCsv).join(',')).join('\r\n');
    await Clipboard.setData(ClipboardData(text: csv));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Data CSV disalin ke clipboard')),
    );
  }

  String _escapeCsv(String value) => '"${value.replaceAll('"', '""')}"';

  String _formatDateTime(DateTime value) {
    final local = value.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day/$month/${local.year} $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredRentals;
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Riwayat Sewa', style: AppType.title),
            Text(
              '${widget.rentals.length} sesi',
              style: AppType.caption.copyWith(
                color: AppColors.neutralTextMuted,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: widget.onRefresh,
            icon: const Icon(Icons.refresh),
            tooltip: 'Muat ulang',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: widget.onRefresh,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppSize.contentMax),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isExpanded = constraints.maxWidth >= 900;
                return ListView(
                  padding: const EdgeInsets.all(AppSpace.s4),
                  children: [
                    _buildFilters(isExpanded),
                    const SizedBox(height: AppSpace.s3),
                    if (filtered.isEmpty)
                      const SizedBox(
                        height: 360,
                        child: DesignEmptyState(
                          icon: Icons.search_off,
                          title: 'Tidak ada sesi ditemukan',
                          message:
                              'Ubah kata pencarian atau filter untuk melihat sesi lainnya.',
                        ),
                      )
                    else if (isExpanded)
                      _buildTable(filtered)
                    else
                      ...filtered.map(_buildRentalCard),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilters(bool isExpanded) {
    final searchField = SizedBox(
      width: 320,
      child: TextField(
        controller: _searchController,
        onChanged: (_) => setState(() {}),
        decoration: const InputDecoration(
          hintText: 'Cari nama, nomor, atau ID sesi',
          prefixIcon: Icon(Icons.search),
        ),
      ),
    );
    final todayChip = FilterChip(
      label: const Text('Hari ini'),
      selected: _todayOnly,
      onSelected: (value) => setState(() => _todayOnly = value),
    );
    final lockerDropdown = SizedBox(
      width: isExpanded ? 180 : 160,
      child: DropdownButtonFormField<String>(
        key: ValueKey(_effectiveLockerFilter),
        initialValue: _effectiveLockerFilter,
        isExpanded: true,
        decoration: const InputDecoration(
          contentPadding: EdgeInsets.symmetric(
            horizontal: AppSpace.s3,
            vertical: AppSpace.s2,
          ),
        ),
        items: _lockerOptions
            .map(
              (locker) => DropdownMenuItem(
                value: locker,
                child: Text(locker, overflow: TextOverflow.ellipsis),
              ),
            )
            .toList(),
        onChanged: (value) {
          if (value != null) setState(() => _lockerFilter = value);
        },
      ),
    );
    final statusDropdown = SizedBox(
      width: isExpanded ? 180 : 160,
      child: DropdownButtonFormField<_RentalStatusFilter>(
        initialValue: _statusFilter,
        isExpanded: true,
        decoration: const InputDecoration(
          contentPadding: EdgeInsets.symmetric(
            horizontal: AppSpace.s3,
            vertical: AppSpace.s2,
          ),
        ),
        items: const [
          DropdownMenuItem(
            value: _RentalStatusFilter.all,
            child: Text('Semua status'),
          ),
          DropdownMenuItem(
            value: _RentalStatusFilter.active,
            child: Text('Berjalan'),
          ),
          DropdownMenuItem(
            value: _RentalStatusFilter.completed,
            child: Text('Selesai'),
          ),
        ],
        onChanged: (value) {
          if (value != null) setState(() => _statusFilter = value);
        },
      ),
    );
    final copyButton = OutlinedButton.icon(
      onPressed: _copyCsv,
      icon: const Icon(Icons.content_copy),
      label: const Text('Salin CSV'),
    );

    if (isExpanded) {
      return Wrap(
        spacing: AppSpace.s2,
        runSpacing: AppSpace.s2,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          searchField,
          todayChip,
          lockerDropdown,
          statusDropdown,
          copyButton,
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: double.infinity,
          child: TextField(
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              hintText: 'Cari nama, nomor, atau ID sesi',
              prefixIcon: Icon(Icons.search),
            ),
          ),
        ),
        const SizedBox(height: AppSpace.s2),
        Wrap(
          spacing: AppSpace.s2,
          runSpacing: AppSpace.s2,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [todayChip, lockerDropdown, statusDropdown, copyButton],
        ),
      ],
    );
  }

  Widget _buildRentalCard(RentalRecord rental) {
    final active = rental.endedAt == null;
    final style = active ? AppStatus.info : AppStatus.success;
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpace.s2),
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '#${rental.rentalId}',
                    style: AppType.bodyStrong.copyWith(
                      color: AppColors.brandPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                DesignStatusBadge(
                  label: active ? 'Berjalan' : 'Selesai',
                  style: style,
                ),
              ],
            ),
            const SizedBox(height: AppSpace.s2),
            Text(
              '${rental.lockerId} · ${rental.nama}',
              style: AppType.bodyStrong,
            ),
            const SizedBox(height: AppSpace.s1),
            Text(
              rental.noHp,
              style: AppType.caption.copyWith(
                color: AppColors.neutralTextMuted,
              ),
            ),
            const SizedBox(height: AppSpace.s2),
            Text(
              active
                  ? '${_formatDateTime(rental.startedAt)} · sekarang · ${rental.displayDuration}'
                  : '${_formatDateTime(rental.startedAt)} – ${_formatDateTime(rental.endedAt!)} · ${rental.displayDuration}',
              style: AppType.caption.copyWith(color: AppColors.neutralTextBody),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTable(List<RentalRecord> rentals) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: const WidgetStatePropertyAll(
            AppColors.neutralSurfaceMuted,
          ),
          columns: const [
            DataColumn(label: Text('ID Sesi')),
            DataColumn(label: Text('Locker')),
            DataColumn(label: Text('Penyewa')),
            DataColumn(label: Text('Telepon')),
            DataColumn(label: Text('Mulai')),
            DataColumn(label: Text('Selesai')),
            DataColumn(label: Text('Durasi')),
            DataColumn(label: Text('Status')),
          ],
          rows: rentals.map((rental) {
            final active = rental.endedAt == null;
            final style = active ? AppStatus.info : AppStatus.success;
            return DataRow(
              cells: [
                DataCell(
                  Text(
                    rental.rentalId,
                    style: const TextStyle(color: AppColors.brandPrimary),
                  ),
                ),
                DataCell(Text(rental.lockerId)),
                DataCell(Text(rental.nama)),
                DataCell(Text(rental.noHp)),
                DataCell(Text(_formatDateTime(rental.startedAt))),
                DataCell(
                  Text(
                    rental.endedAt == null
                        ? 'Sekarang'
                        : _formatDateTime(rental.endedAt!),
                  ),
                ),
                DataCell(Text(rental.displayDuration)),
                DataCell(
                  DesignStatusBadge(
                    label: active ? 'Berjalan' : 'Selesai',
                    style: style,
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}
