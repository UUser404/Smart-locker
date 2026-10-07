class RentalRecord {
  final String rentalId;
  final String lockerId;
  final String nama;
  final String noHp;
  final DateTime startedAt;
  final DateTime? endedAt;
  final int? totalDurationSeconds;
  final String status; // 'active'|'completed'|'expired'

  RentalRecord({
    required this.rentalId,
    required this.lockerId,
    required this.nama,
    required this.noHp,
    required this.startedAt,
    this.endedAt,
    this.totalDurationSeconds,
    this.status = 'active',
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

  /// Dari response Express `/api/admin/reports/rentals`:
  /// {
  ///   "rental_id": "...", "locker_id": "...", "nama": "...",
  ///   "no_hp": "0812****89",  // di-mask oleh backend
  ///   "started_at": "...", "ended_at": null,
  ///   "total_duration_seconds": null, "status": "active"
  /// }
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
    status: json['status'] as String? ?? 'active',
  );
}

class RentalStats {
  final int totalRentals;
  final int avgDurationSeconds;
  final String? busiestLockerId; // nullable — kadang backend kirim null

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
