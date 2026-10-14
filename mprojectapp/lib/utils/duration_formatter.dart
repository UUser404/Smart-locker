/// Helper untuk format durasi secara adaptif.
///
/// Format:
/// - < 1 menit   → "45s"
/// - < 1 jam     → "5m 20s"
/// - < 1 hari    → "2j 15m"
/// - < 30 hari   → "5h 8j"
/// - >= 30 hari  → "1bl 12j"
///
/// Maksimal 2 unit waktu yang ditampilkan.
///
/// Keterangan:
/// - bl = bulan (30 hari)
/// - h  = hari
/// - j  = jam
/// - m  = menit
/// - s  = detik
String formatDuration(Duration d) {
  if (d.inSeconds < 0) return '-';

  // >= 30 hari → bulan + hari
  if (d.inDays >= 30) {
    final months = d.inDays ~/ 30;
    final days = d.inDays % 30;
    if (days == 0) return '${months}bl';
    return '${months}bl ${days}j';
  }

  // >= 1 hari → hari + jam
  if (d.inDays >= 1) {
    final hours = d.inHours % 24;
    if (hours == 0) return '${d.inDays}h';
    return '${d.inDays}h ${hours}j';
  }

  // >= 1 jam → jam + menit
  if (d.inHours >= 1) {
    final minutes = d.inMinutes % 60;
    if (minutes == 0) return '${d.inHours}j';
    return '${d.inHours}j ${minutes}m';
  }

  // >= 1 menit → menit + detik
  if (d.inMinutes >= 1) {
    final seconds = d.inSeconds % 60;
    if (seconds == 0) return '${d.inMinutes}m';
    return '${d.inMinutes}m ${seconds}s';
  }

  // < 1 menit → detik
  return '${d.inSeconds}s';
}
