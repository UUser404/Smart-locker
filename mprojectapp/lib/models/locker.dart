import 'package:cloud_firestore/cloud_firestore.dart';

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
  final DateTime? unlockedSince;
  final DateTime? needsAttentionSince; // ← tetap DateTime (raw)
  final String? currentRentalId;

  // Field Firestore:
  final String? controllerId;
  final int? lockerIndex;
  final bool pendingEnd;

  Locker({
    required this.lockerId,
    required this.status,
    this.elapsedSeconds,
    this.unlockedSince,
    this.needsAttentionSince,
    this.currentRentalId,
    this.controllerId,
    this.lockerIndex,
    this.pendingEnd = false,
  });

  // ===== DERIVED GETTERS (untuk UI) =====

  /// Durasi terformat. Hitung live dari `unlockedSince` kalau
  /// `elapsedSeconds` null (kondisi aktual di Firestore).
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
  String get needsAttentionSinceLabel {
    if (needsAttentionSince == null) return '-';
    final d = DateTime.now().difference(needsAttentionSince!);
    if (d.inMinutes < 1) return 'baru saja';
    if (d.inHours < 1) return '${d.inMinutes} menit lalu';
    if (d.inDays < 1) return '${d.inHours} jam lalu';
    return '${d.inDays} hari lalu';
  }

  // ===== FIREBASE =====
  factory Locker.fromFirestore(DocumentSnapshot doc) {
    final d = (doc.data() as Map<String, dynamic>?) ?? {};
    return Locker(
      lockerId: doc.id,
      status: lockerStatusFromString(d['status'] as String? ?? 'empty'),
      elapsedSeconds: d['elapsedSeconds'] as int?,
      unlockedSince: (d['unlockedSince'] as Timestamp?)?.toDate(),
      needsAttentionSince: (d['needsAttentionSince'] as Timestamp?)?.toDate(),
      currentRentalId: d['currentRentalId'] as String?,
      controllerId: d['controllerId'] as String?,
      lockerIndex: d['lockerIndex'] as int?,
      pendingEnd: d['pendingEnd'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toFirestore() => {
    'status': _statusToString(status),
    'currentRentalId': currentRentalId,
    'controllerId': controllerId,
    'lockerIndex': lockerIndex,
    'pendingEnd': pendingEnd,
    'unlockedSince': unlockedSince == null
        ? null
        : Timestamp.fromDate(unlockedSince!),
    'needsAttentionSince': needsAttentionSince == null
        ? null
        : Timestamp.fromDate(needsAttentionSince!),
  };

  static String _statusToString(LockerStatus s) {
    switch (s) {
      case LockerStatus.empty:
        return 'empty';
      case LockerStatus.occupied:
        return 'occupied';
      case LockerStatus.needsAttention:
        return 'needs_attention';
    }
  }

  // ===== JSON (untuk REST fallback) =====
  factory Locker.fromJson(Map<String, dynamic> json) => Locker(
    lockerId: json['locker_id'] as String,
    status: lockerStatusFromString(json['status'] as String),
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
