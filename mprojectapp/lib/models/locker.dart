enum LockerStatus { empty, occupied, needsAttention }

LockerStatus lockerStatusFromString(String s) {
  switch (s) {
    case 'empty':
      return LockerStatus.empty;
    case 'occupied':
      return LockerStatus.occupied;
    case 'needs_attention':
      return LockerStatus.needsAttention;
    default:
      return LockerStatus.empty;
  }
}

class Locker {
  final String lockerId;
  final LockerStatus status;
  final int? elapsedSeconds;
  final DateTime?
  unlockedSince; // dari field `unlocked_since` (needs_attention)
  final DateTime? needsAttentionSince;
  final String? currentRentalId;

  Locker({
    required this.lockerId,
    required this.status,
    this.elapsedSeconds,
    this.unlockedSince,
    this.needsAttentionSince,
    this.currentRentalId,
  });

  // ============ DERIVED GETTERS (untuk UI) ============

  /// Durasi terformat. Untuk `occupied`, backend sudah kirim `elapsed_seconds`.
  /// Kalau kosong, hitung live dari `unlockedSince`.
  String get displayDuration {
    Duration d;
    if (elapsedSeconds != null) {
      d = Duration(seconds: elapsedSeconds!);
    } else if (unlockedSince != null) {
      d = DateTime.now().difference(unlockedSince!);
    } else {
      return '-';
    }
    if (d.inHours > 0) return '${d.inHours}j ${d.inMinutes % 60}m';
    if (d.inMinutes > 0) return '${d.inMinutes}m ${d.inSeconds % 60}s';
    return '${d.inSeconds}s';
  }

  /// Label "sejak ..." untuk needs_attention.
  /// Pakai `unlockedSince` karena backend kirim field itu (sesuai API.md 10.3).
  String get needsAttentionSinceLabel {
    final ref = needsAttentionSince ?? unlockedSince;
    if (ref == null) return '-';
    final d = DateTime.now().difference(ref);
    if (d.inMinutes < 1) return 'baru saja';
    if (d.inHours < 1) return '${d.inMinutes} menit lalu';
    if (d.inDays < 1) return '${d.inHours} jam lalu';
    return '${d.inDays} hari lalu';
  }

  // ============ DARI EXPRESS `/api/admin/lockers` ============
  /// Contoh response (API.md 10.3):
  /// { "locker_id": "locker_01", "status": "empty" }
  /// { "locker_id": "locker_02", "status": "needs_attention",
  ///   "unlocked_since": "2026-09-16T10:05:00Z" }
  /// { "locker_id": "locker_03", "status": "occupied", "elapsed_seconds": 620 }
  factory Locker.fromJson(Map<String, dynamic> json) => Locker(
    lockerId: json['locker_id'] as String,
    status: lockerStatusFromString(json['status'] as String? ?? 'empty'),
    elapsedSeconds: json['elapsed_seconds'] as int?,
    unlockedSince: json['unlocked_since'] == null
        ? null
        : DateTime.parse(json['unlocked_since'] as String),
    needsAttentionSince: json['needs_attention_since'] == null
        ? null
        : DateTime.parse(json['needs_attention_since'] as String),
    currentRentalId: json['current_rental_id'] as String?,
  );
}
