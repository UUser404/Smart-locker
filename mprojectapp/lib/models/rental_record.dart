import 'package:cloud_firestore/cloud_firestore.dart';

class RentalRecord {
  final String rentalId;
  final String lockerId;
  final String nama;
  final String noHp;
  final DateTime startedAt;
  final DateTime? endedAt;
  final int? totalDurationSeconds;
  final String status;
  final DateTime? lastAccessAt;
  final String? accessAction;

  RentalRecord({
    required this.rentalId,
    required this.lockerId,
    required this.nama,
    required this.noHp,
    required this.startedAt,
    this.endedAt,
    this.totalDurationSeconds,
    this.status = 'active',
    this.lastAccessAt,
    this.accessAction,
  });

  Duration? get duration {
    if (totalDurationSeconds != null) {
      return Duration(seconds: totalDurationSeconds!);
    }
    if (endedAt != null) {
      return endedAt!.difference(startedAt);
    }
    return null;
  }

  /// String terformat untuk ditampilkan di UI.
  String get displayDuration {
    final d = duration;
    if (d == null) return '-';
    if (d.inHours > 0) return '${d.inHours}j ${d.inMinutes % 60}m';
    if (d.inMinutes > 0) return '${d.inMinutes}m';
    return '${d.inSeconds}s';
  }

  // ===== FIREBASE =====
  factory RentalRecord.fromFirestore(DocumentSnapshot doc) {
    final d = (doc.data() as Map<String, dynamic>?) ?? {};
    final startedAt = d['startedAt'];
    return RentalRecord(
      rentalId: (d['rentalId'] as String?) ?? doc.id,
      lockerId: d['lockerId'] as String? ?? '',
      nama: d['nama'] as String? ?? '',
      noHp: d['noHp'] as String? ?? '',
      startedAt: startedAt is Timestamp
          ? startedAt.toDate()
          : DateTime.now(), // fallback aman kalau data korup
      endedAt: (d['endedAt'] as Timestamp?)?.toDate(),
      totalDurationSeconds: d['totalDurationSeconds'] as int?,
      status: d['status'] as String? ?? 'active',
      lastAccessAt: (d['lastAccessAt'] as Timestamp?)?.toDate(),
      accessAction: d['accessAction'] as String?,
    );
  }

  // ===== JSON (untuk REST fallback) =====
  factory RentalRecord.fromJson(Map<String, dynamic> json) => RentalRecord(
    rentalId: json['rental_id'] as String,
    lockerId: json['locker_id'] as String,
    nama: json['nama'] as String,
    noHp: json['no_hp'] as String,
    startedAt: DateTime.parse(json['started_at'] as String),
    endedAt: json['ended_at'] == null
        ? null
        : DateTime.parse(json['ended_at'] as String),
    totalDurationSeconds: json['total_duration_seconds'] as int?,
  );
}

class RentalStats {
  final int totalRentals;
  final int avgDurationSeconds;
  final String? busiestLockerId; // ← nullable (sesuai pemakaian)

  RentalStats({
    required this.totalRentals,
    required this.avgDurationSeconds,
    this.busiestLockerId,
  });

  String get displayAvgDuration {
    if (avgDurationSeconds <= 0) return '-';
    final d = Duration(seconds: avgDurationSeconds);
    if (d.inHours > 0) return '${d.inHours}j ${d.inMinutes % 60}m';
    if (d.inMinutes > 0) return '${d.inMinutes} menit';
    return '${d.inSeconds}s';
  }

  factory RentalStats.fromJson(Map<String, dynamic> json) => RentalStats(
    totalRentals: json['total_rentals'] as int,
    avgDurationSeconds: json['avg_duration_seconds'] as int,
    busiestLockerId: json['busiest_locker_id'] as String?,
  );
}
