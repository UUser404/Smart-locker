import 'dart:async';

import 'package:flutter/gestures.dart' show kLongPressTimeout;
import 'package:flutter/material.dart';

import '../models/controller_status.dart';
import '../models/locker.dart';
import '../theme/app_theme.dart';
import '../theme/app_tokens.dart';
import '../widgets/design_system_widgets.dart';

class LockerDetailScreen extends StatelessWidget {
  const LockerDetailScreen({
    required this.locker,
    required this.onHandle,
    required this.onEmergencyOpen,
    this.deviceStatus,
    super.key,
  });

  final Locker locker;
  final ControllerStatus? deviceStatus;
  final Future<bool> Function() onHandle;
  final Future<void> Function(String reason, bool endSession) onEmergencyOpen;

  @override
  Widget build(BuildContext context) {
    final style = lockerStatusStyle(locker.status);
    final isOccupied = locker.status == LockerStatus.occupied;
    final isAttention = locker.status == LockerStatus.needsAttention;
    final connection = deviceStatus == null
        ? 'Belum ada data'
        : deviceStatus!.online
        ? 'Online'
        : 'Offline';

    return Scaffold(
      appBar: AppBar(title: Text(locker.lockerId)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpace.s4),
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpace.s4),
            decoration: BoxDecoration(
              color: style.tint,
              borderRadius: BorderRadius.circular(AppRadius.hero),
              border: Border.all(color: style.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DesignStatusBadge(
                  label: lockerStatusLabel(locker.status),
                  style: style,
                ),
                const SizedBox(height: AppSpace.s3),
                Text(
                  isAttention
                      ? locker.needsAttentionSinceLabel
                      : isOccupied
                      ? locker.displayDuration
                      : 'Siap digunakan',
                  style: AppType.display.copyWith(color: style.strong),
                ),
                const SizedBox(height: AppSpace.s2),
                Text(
                  isAttention
                      ? 'Locker memerlukan pemeriksaan petugas.'
                      : isOccupied
                      ? 'Sesi sewa sedang berjalan.'
                      : 'Locker tersedia untuk disewa.',
                  style: AppType.caption.copyWith(
                    color: AppColors.neutralTextMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.s4),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpace.s4),
              child: Column(
                children: [
                  _InfoRow(label: 'Status perangkat', value: connection),
                  const Divider(height: AppSpace.s6),
                  _InfoRow(
                    label: 'Koneksi ESP32',
                    value: deviceStatus?.lastSeenAt == null
                        ? 'Belum pernah tersambung'
                        : 'Sync ${_formatLastSeen(deviceStatus!.lastSeenAt!)}',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpace.s4),
          if (isAttention)
            FilledButton.icon(
              onPressed: () async {
                final resolved = await onHandle();
                if (resolved && context.mounted) {
                  Navigator.of(context).pop();
                }
              },
              icon: const Icon(Icons.checklist),
              label: const Text('Tangani sekarang'),
            )
          else if (isOccupied)
            _EmergencyActionCard(
              locker: locker,
              onEmergencyOpen: onEmergencyOpen,
            ),
        ],
      ),
    );
  }

  String _formatLastSeen(DateTime value) {
    final seconds = DateTime.now().difference(value).inSeconds;
    if (seconds < 5) return 'baru saja';
    if (seconds < 60) return '$seconds detik lalu';
    return '${(seconds / 60).floor()} menit lalu';
  }
}

class LockerHandlingScreen extends StatefulWidget {
  const LockerHandlingScreen({
    required this.locker,
    required this.onResolve,
    super.key,
  });

  final Locker locker;
  final Future<void> Function() onResolve;

  @override
  State<LockerHandlingScreen> createState() => _LockerHandlingScreenState();
}

class _LockerHandlingScreenState extends State<LockerHandlingScreen> {
  bool _checkedPhysically = false;
  bool _confirmedEmpty = false;
  bool _submitting = false;

  Future<void> _confirmResolve() async {
    if (!_checkedPhysically || !_confirmedEmpty || _submitting) return;

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) =>
          _ResolveConfirmationSheet(lockerId: widget.locker.lockerId),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _submitting = true);
    try {
      await widget.onResolve();
      if (mounted) Navigator.of(context).pop(true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final style = AppStatus.warning;
    final canResolve = _checkedPhysically && _confirmedEmpty && !_submitting;

    return Scaffold(
      appBar: AppBar(title: Text('Penanganan ${widget.locker.lockerId}')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.s4,
          AppSpace.s2,
          AppSpace.s4,
          180,
        ),
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpace.s4),
            decoration: BoxDecoration(
              color: style.tint,
              borderRadius: BorderRadius.circular(AppRadius.hero),
              border: Border.all(color: style.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PERLU TINDAKAN',
                  style: AppType.overline.copyWith(color: style.text),
                ),
                const SizedBox(height: AppSpace.s2),
                Text(
                  widget.locker.needsAttentionSinceLabel,
                  style: AppType.display.copyWith(color: style.strong),
                ),
                const SizedBox(height: AppSpace.s2),
                Text(
                  'Pastikan kondisi locker aman sebelum menyelesaikan pemeriksaan.',
                  style: AppType.caption.copyWith(
                    color: AppColors.neutralTextMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.s4),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpace.s4),
              child: const _InfoRow(
                label: 'Sensor pintu',
                value: 'Status belum tersedia',
              ),
            ),
          ),
          const SizedBox(height: AppSpace.s6),
          const DesignSectionHeader(title: 'Langkah penanganan'),
          const SizedBox(height: AppSpace.s2),
          _ChecklistTile(
            title: 'Cek fisik pintu ${widget.locker.lockerId}',
            subtitle: 'Pastikan tidak ada yang menghalangi.',
            checked: _checkedPhysically,
            onChanged: (value) =>
                setState(() => _checkedPhysically = value ?? false),
          ),
          const SizedBox(height: AppSpace.s2),
          _ChecklistTile(
            title: 'Pastikan isi locker aman atau kosong',
            subtitle: 'Pastikan tidak ada barang pelanggan tertinggal.',
            checked: _confirmedEmpty,
            onChanged: (value) =>
                setState(() => _confirmedEmpty = value ?? false),
          ),
          const SizedBox(height: AppSpace.s2),
          const Card(
            child: ListTile(
              leading: Icon(Icons.sensors, color: AppColors.neutralTextMuted),
              title: Text('Penutupan pintu otomatis'),
              subtitle: Text('Konfirmasi sensor belum tersedia dari API.'),
            ),
          ),
        ],
      ),
      bottomSheet: SafeArea(
        child: Container(
          padding: const EdgeInsets.all(AppSpace.s4),
          decoration: const BoxDecoration(
            color: AppColors.neutralSurface,
            border: Border(top: BorderSide(color: AppColors.neutralBorder)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!canResolve)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpace.s2),
                  child: Text(
                    'Selesaikan kedua pemeriksaan untuk mengaktifkan tombol.',
                    style: AppType.caption.copyWith(
                      color: AppColors.warningText,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              FilledButton(
                onPressed: canResolve ? _confirmResolve : null,
                child: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Selesaikan & kosongkan locker'),
              ),
              const SizedBox(height: AppSpace.s2),
              OutlinedButton(
                onPressed: _submitting
                    ? null
                    : () => Navigator.of(context).pop(),
                child: const Text('Kembali'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResolveConfirmationSheet extends StatelessWidget {
  const _ResolveConfirmationSheet({required this.lockerId});

  final String lockerId;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.s4,
          AppSpace.s4,
          AppSpace.s4,
          AppSpace.s6,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Kosongkan $lockerId?',
              style: AppType.title,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpace.s2),
            Text(
              'Status locker akan diubah menjadi kosong.',
              style: AppType.bodySm.copyWith(color: AppColors.neutralTextMuted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpace.s4),
            const _InfoRow(label: 'Dicatat atas nama', value: 'Petugas masuk'),
            const SizedBox(height: AppSpace.s4),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Ya, kosongkan locker'),
            ),
            const SizedBox(height: AppSpace.s2),
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Batal'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChecklistTile extends StatelessWidget {
  const _ChecklistTile({
    required this.title,
    required this.subtitle,
    required this.checked,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool checked;
  final ValueChanged<bool?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: CheckboxListTile(
        value: checked,
        onChanged: onChanged,
        controlAffinity: ListTileControlAffinity.leading,
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpace.s3),
        title: Text(title, style: AppType.bodyStrong),
        subtitle: Text(subtitle, style: AppType.caption),
      ),
    );
  }
}

class _EmergencyActionCard extends StatelessWidget {
  const _EmergencyActionCard({
    required this.locker,
    required this.onEmergencyOpen,
  });

  final Locker locker;
  final Future<void> Function(String reason, bool endSession) onEmergencyOpen;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpace.s4),
      decoration: BoxDecoration(
        color: AppColors.dangerTint,
        borderRadius: BorderRadius.circular(AppRadius.hero),
        border: Border.all(color: AppColors.dangerBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Buka darurat',
            style: AppType.subtitle.copyWith(color: AppColors.dangerText),
          ),
          const SizedBox(height: AppSpace.s1),
          Text(
            'Aksi tercatat dan hanya digunakan jika pelanggan tidak bisa membuka locker.',
            style: AppType.caption.copyWith(color: AppColors.neutralTextBody),
          ),
          const SizedBox(height: AppSpace.s3),
          OutlinedButton(
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              builder: (_) => _EmergencyActionSheet(
                locker: locker,
                onEmergencyOpen: onEmergencyOpen,
              ),
            ),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(AppSize.buttonMd),
              side: const BorderSide(color: AppColors.dangerMain),
              foregroundColor: AppColors.dangerMain,
            ),
            child: Text('Buka darurat ${locker.lockerId}'),
          ),
        ],
      ),
    );
  }
}

class _EmergencyActionSheet extends StatefulWidget {
  const _EmergencyActionSheet({
    required this.locker,
    required this.onEmergencyOpen,
  });

  final Locker locker;
  final Future<void> Function(String reason, bool endSession) onEmergencyOpen;

  @override
  State<_EmergencyActionSheet> createState() => _EmergencyActionSheetState();
}

class _EmergencyActionSheetState extends State<_EmergencyActionSheet> {
  String _reason = 'Lupa kode';
  bool _endSession = false;
  bool _submitting = false;
  double _holdProgress = 0;
  String? _errorMessage;
  Timer? _holdTimer;
  Timer? _progressTimer;

  @override
  void dispose() {
    _holdTimer?.cancel();
    _progressTimer?.cancel();
    super.dispose();
  }

  void _startHold({Duration elapsedBeforeStart = Duration.zero}) {
    if (_submitting || _holdTimer != null) return;

    final totalHoldMs = AppMotion.holdToConfirm.inMilliseconds;
    final elapsedMs = elapsedBeforeStart.inMilliseconds;
    final remaining = AppMotion.holdToConfirm - elapsedBeforeStart;
    if (remaining <= Duration.zero) return;

    setState(() {
      _holdProgress = elapsedMs / totalHoldMs;
      _errorMessage = null;
    });

    const progressInterval = Duration(milliseconds: 50);
    _progressTimer = Timer.periodic(progressInterval, (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _holdProgress =
            (_holdProgress + progressInterval.inMilliseconds / totalHoldMs)
                .clamp(0.0, 1.0)
                .toDouble();
      });
    });
    _holdTimer = Timer(remaining, () {
      _holdTimer = null;
      _progressTimer?.cancel();
      _progressTimer = null;
      if (!mounted) return;
      setState(() => _holdProgress = 1);
      _submitEmergencyOpen();
    });
  }

  void _cancelHold() {
    if (_holdTimer == null) return;
    _holdTimer!.cancel();
    _holdTimer = null;
    _progressTimer?.cancel();
    _progressTimer = null;
    if (mounted) setState(() => _holdProgress = 0);
  }

  Future<void> _submitEmergencyOpen() async {
    if (_submitting) return;
    setState(() {
      _submitting = true;
      _errorMessage = null;
    });

    try {
      await widget.onEmergencyOpen(_reason, _endSession);
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        setState(() {
          _holdProgress = 0;
          _errorMessage = error.toString();
        });
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.s4,
          AppSpace.s2,
          AppSpace.s4,
          AppSpace.s6,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Buka darurat ${widget.locker.lockerId}',
              style: AppType.title,
            ),
            const SizedBox(height: AppSpace.s1),
            Text(
              'Durasi sewa · ${widget.locker.displayDuration}',
              style: AppType.caption.copyWith(
                color: AppColors.neutralTextMuted,
              ),
            ),
            const SizedBox(height: AppSpace.s4),
            Text('Alasan (wajib)', style: AppType.bodyStrong),
            const SizedBox(height: AppSpace.s2),
            Wrap(
              spacing: AppSpace.s2,
              runSpacing: AppSpace.s2,
              children: [
                for (final reason in [
                  'Lupa kode',
                  'Pintu macet',
                  'Keadaan darurat',
                  'Lainnya',
                ])
                  ChoiceChip(
                    label: Text(reason),
                    selected: _reason == reason,
                    onSelected: (_) => setState(() => _reason = reason),
                    selectedColor: AppColors.dangerContainer,
                    labelStyle: TextStyle(
                      color: _reason == reason
                          ? AppColors.dangerText
                          : AppColors.neutralTextBody,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpace.s4),
            Text('Setelah pintu dibuka', style: AppType.bodyStrong),
            const SizedBox(height: AppSpace.s2),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('Sesi tetap berjalan')),
                ButtonSegment(value: true, label: Text('Akhiri sesi')),
              ],
              selected: {_endSession},
              onSelectionChanged: (selection) =>
                  setState(() => _endSession = selection.first),
            ),
            const SizedBox(height: AppSpace.s4),
            Container(
              padding: const EdgeInsets.all(AppSpace.s3),
              decoration: BoxDecoration(
                color: AppColors.warningTint,
                borderRadius: BorderRadius.circular(AppRadius.field),
              ),
              child: Text(
                'Perintah akan dicatat atas nama Anda dan dikirim ke locker. Pastikan tindakan ini memang diperlukan.',
                style: AppType.caption.copyWith(color: AppColors.warningText),
              ),
            ),
            const SizedBox(height: AppSpace.s4),
            if (_errorMessage != null) ...[
              Text(
                _errorMessage!,
                style: AppType.caption.copyWith(color: AppColors.dangerText),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpace.s2),
            ],
            Semantics(
              button: true,
              enabled: !_submitting,
              label: 'Tahan 2 detik untuk membuka locker darurat',
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onLongPressStart: (_) =>
                    _startHold(elapsedBeforeStart: kLongPressTimeout),
                onLongPressEnd: (_) => _cancelHold(),
                onLongPressCancel: _cancelHold,
                child: Container(
                  constraints: const BoxConstraints(
                    minHeight: AppSize.buttonMd,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.dangerMain,
                    borderRadius: BorderRadius.circular(AppRadius.button),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpace.s4,
                    vertical: AppSpace.s3,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _submitting
                            ? 'Mengirim perintah...'
                            : _holdProgress > 0
                            ? 'Tahan... ${(_holdProgress * 100).round()}%'
                            : 'Tahan 2 detik untuk membuka',
                        textAlign: TextAlign.center,
                        style: AppType.bodyStrong.copyWith(
                          color: AppColors.neutralOnInverse,
                        ),
                      ),
                      if (_submitting) ...[
                        const SizedBox(height: AppSpace.s2),
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.neutralOnInverse,
                          ),
                        ),
                      ] else if (_holdProgress > 0) ...[
                        const SizedBox(height: AppSpace.s2),
                        LinearProgressIndicator(
                          value: _holdProgress,
                          color: AppColors.neutralOnInverse,
                          backgroundColor: AppColors.dangerContainer,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpace.s2),
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Batal'),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: AppType.bodySm.copyWith(color: AppColors.neutralTextMuted),
          ),
        ),
        const SizedBox(width: AppSpace.s2),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: AppType.bodyStrong,
          ),
        ),
      ],
    );
  }
}
