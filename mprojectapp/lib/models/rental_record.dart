class RentalRecord {
  final String rentalId;
  final String lockerId;
  final String nama;
  final String noHp;
  final DateTime startedAt;
  final DateTime? endedAt;
  final int? totalDurationSeconds;

  RentalRecord({
    required this.rentalId,
    required this.lockerId,
    required this.nama,
    required this.noHp,
    required this.startedAt,
    this.endedAt,
    this.totalDurationSeconds,
  });

  factory RentalRecord.fromJson(Map<String, dynamic> json) {
    return RentalRecord(
      rentalId: json['rental_id'] as String,
      lockerId: json['locker_id'] as String,
      nama: json['nama'] as String,
      noHp: json['no_hp'] as String,
      startedAt: DateTime.parse(json['started_at'] as String),
      endedAt: json['ended_at'] != null
          ? DateTime.parse(json['ended_at'] as String)
          : null,
      totalDurationSeconds: json['total_duration_seconds'] as int?,
    );
  }

  String get displayDuration {
    if (totalDurationSeconds == null) return '-';
    final d = Duration(seconds: totalDurationSeconds!);
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    if (h > 0) return '${h}j ${m}m';
    return '${m}m';
  }
}

/// Ringkasan statistik untuk kartu di bagian atas layar laporan admin.
class RentalStats {
  final int totalRentals;
  final double avgDurationSeconds;
  final String? busiestLockerId;

  RentalStats({
    required this.totalRentals,
    required this.avgDurationSeconds,
    this.busiestLockerId,
  });

  factory RentalStats.fromJson(Map<String, dynamic> json) {
    return RentalStats(
      totalRentals: json['total_rentals'] as int,
      avgDurationSeconds: (json['avg_duration_seconds'] as num).toDouble(),
      busiestLockerId: json['busiest_locker_id'] as String?,
    );
  }

  String get displayAvgDuration {
    final d = Duration(seconds: avgDurationSeconds.round());
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    if (h > 0) return '${h}j ${m}m';
    return '${m}m';
  }
}
