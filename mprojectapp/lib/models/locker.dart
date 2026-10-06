enum LockerStatus { empty, occupied, needsAttention, unknown }

LockerStatus lockerStatusFromString(String value) {
  switch (value) {
    case 'empty':
      return LockerStatus.empty;
    case 'occupied':
      return LockerStatus.occupied;
    case 'needs_attention':
      return LockerStatus.needsAttention;
    default:
      return LockerStatus.unknown;
  }
}

class Locker {
  final String lockerId;
  final LockerStatus status;
  final int? elapsedSeconds; // hanya ada saat status == occupied
  final DateTime? unlockedSince; // hanya ada saat status == needsAttention

  Locker({
    required this.lockerId,
    required this.status,
    this.elapsedSeconds,
    this.unlockedSince,
  });

  factory Locker.fromJson(Map<String, dynamic> json) {
    return Locker(
      lockerId: json['locker_id'] as String,
      status: lockerStatusFromString(json['status'] as String),
      elapsedSeconds: json['elapsed_seconds'] as int?,
      unlockedSince: json['unlocked_since'] != null
          ? DateTime.tryParse(json['unlocked_since'] as String)
          : null,
    );
  }

  String get displayDuration {
    if (elapsedSeconds == null) return '-';
    final d = Duration(seconds: elapsedSeconds!);
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) {
      return '${h}j ${m}m ${s}d';
    }
    return '${m}m ${s}d';
  }

  String get needsAttentionSince {
    if (unlockedSince == null) return '-';
    final diff = DateTime.now().toUtc().difference(unlockedSince!.toUtc());
    if (diff.inMinutes < 1) return 'baru saja';
    if (diff.inMinutes < 60) return '${diff.inMinutes} menit lalu';
    return '${diff.inHours} jam lalu';
  }
}
