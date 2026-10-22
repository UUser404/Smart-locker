# Desain Notifikasi Smart Locker

Berdasarkan materi PBP 6 — Notification & Design Decisions.

## Tabel Desain Notifikasi

| Kondisi                                                       | Tingkat               | Jenis Peringatan                                                                                                                                                                                            | Persona                                    |
| :------------------------------------------------------------ | :-------------------- | :---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | :----------------------------------------- |
| Locker `needs_attention` <br>(pintu tidak tertutup > 2 menit) | **Bahaya**            | Push notification prioritas tinggi, collapse key + tag, TTL (target 30 menit; kode saat ini 1 jam), channel `smart_locker_alert` (bunyi + getar). <br>Isi: _"Locker XX — pintu terbuka sejak N menit lalu"_ | Petugas Keamanan & Kebersihan (HP Android) |
| Locker masih `needs_attention` <br>(belum di-resolve petugas) | **Bahaya (lanjutan)** | Reminder tiap 1 menit, **silent** (channel `smart_locker_reminder`, importance Low), `tag` sama → accordion: body ter-update, 1 locker = 1 slot di tray. Berhenti otomatis saat di-resolve.                 | Petugas Keamanan & Kebersihan (HP Android) |
| Petugas login saat ada locker `needs_attention`               | **Bahaya (susulan)**  | Catch-up (`data.mode = catchup`): FCM channel alert (bunyi sekali) + snackbar in-app. Petugas bisa menerima 2x — disengaja sebagai redundansi.                                                              | Petugas Keamanan & Kebersihan (HP Android) |
| Pintu baru terbuka <br>(transisi `closed → open`)             | **Informasi**         | Banner di dashboard petugas + refresh otomatis (tidak push notif)                                                                                                                                           | Petugas                                    |
| Kode unik salah 5x dalam 10 menit                             | **Waspada**           | Banner kuning di web pelanggan + info sisa lock (tidak push notif)                                                                                                                                          | Pelanggan                                  |
| Sesi sewa selesai <br>(user pilih "Akhiri Sewa")              | **Informasi**         | Tampil di riwayat + dashboard admin (tidak push notif)                                                                                                                                                      | Admin                                      |
| Kode unik berhasil dibuat <br>(user sukses rent)              | **Informasi**         | Banner + salin kode di web pelanggan (tidak notif)                                                                                                                                                          | Pelanggan                                  |

## Implementasi di Backend

File: `backend-express/src/services/fcmService.js`

- **Tingkat Bahaya (notif awal)** → `notifyNeedsAttention()`
- **Reminder berkala** → `remindNeedsAttention()`, dipanggil scheduler tiap `REMINDER_INTERVAL_MS` (60 detik). Status locker dicek sebelum kirim; kalau bukan `needs_attention`, di-skip.
- **Catch-up login** → `catchUpForDevice(token)`, dipanggil (fire-and-forget) setelah `POST /api/admin/register-device`
- **Prioritas** → notif awal dan catch-up: `android.priority = "high"` + `apns-priority = "10"`; reminder: `android.priority = "normal"` + `apns-priority = "5"` (`interruption-level = passive`)
- **Collapse key + tag** → `collapseKey = locker_{lockerId}` menggabungkan pesan yang belum terkirim; `android.notification.tag = locker_{lockerId}` adalah kunci accordion di tray (notif baru menggantikan yang lama); iOS memakai `apns-collapse-id`. Dipakai semua jenis kiriman. `collapseKey` saja tidak cukup untuk accordion di tray.
- **TTL** → target desain 30 menit (Android: `ttl = 1800000`), tetapi kode saat ini memakai 1 jam (`ttl = 60 * 60 * 1000`) — belum disamakan
- **Throttle** → `REMINDER_THROTTLE_MS` = 50 detik per locker, sengaja di bawah interval scheduler 60 detik (kalau sama, jitter membuat reminder ter-skip dan efektif tiap 2 menit). State di memori, di-reset saat resolve lewat `resetCooldown()`, dan hanya diperbarui kalau minimal 1 device berhasil menerima. Menggantikan cooldown 10 menit (`NOTIF_COOLDOWN_MS`) yang dihapus karena membuat petugas bisa lupa locker yang masih bermasalah.
- **Channel Android** → `smart_locker_alert` (High, bunyi + getar) untuk notif awal & catch-up; `smart_locker_reminder` (Low, silent) untuk reminder. Dibuat di app Flutter (`main.dart`) via `flutter_local_notifications`.
- **Token yatim** → dibersihkan otomatis (defensive cleanup) saat FCM melaporkan `registration-token-not-registered`; token device yang logout dihapus lewat `POST /api/admin/unregister-device`.

**Alasan desain (alarm fatigue):** notif awal harus bunyi supaya petugas sadar, tapi reminder yang bunyi tiap menit akan membuat petugas mematikan atau mengabaikan notifikasi. Karena itu reminder dipisah ke channel silent dan memakai accordion.

## Skenario Demo (Video 1 Menit)

1. **Izin notifikasi** — dialog pertama, klik Izinkan
2. **Kill app + push notif** — app ditutup, notif tetap masuk
3. **Matiin data + push notif** — HP offline, notif tertahan, muncul saat online

Skenario tambahan (di luar video 1 menit):

4. **Reminder accordion** — tunggu 1–2 menit, body notif ter-update tanpa bunyi, tray tetap 1 slot
5. **Catch-up** — logout lalu login ulang saat locker masih `needs_attention`, notif + snackbar muncul

## Keterbatasan Platform vs Cacat Implementasi

| Masalah                                                          | Klasifikasi                                     | Tindakan                                                                          |
| :--------------------------------------------------------------- | :---------------------------------------------- | :-------------------------------------------------------------------------------- |
| Notif tidak muncul saat app di-force-stop (beberapa ROM Android) | Keterbatasan platform (beberapa OEM aggressive) | Mitigasi: background service / cek battery optimization                           |
| Notif tidak muncul karena lupa izin                              | Cacat implementasi                              | Perbaiki: minta izin saat fitur relevan + penjelasan                              |
| Notif web di iPhone butuh install ke home screen                 | Keterbatasan platform (iOS)                     | Mitigasi: pakai app native untuk iOS (di luar scope)                              |
| Notif tidak masuk saat device offline > TTL                      | Keterbatasan platform (FCM)                     | Mitigasi: atur TTL (target 30 menit; kode saat ini 1 jam)                         |
| Reminder bunyi tiap menit                                        | Cacat implementasi                              | Perbaiki: pastikan reminder memakai channel `smart_locker_reminder` (Low)         |
| Device yang sudah logout masih menerima notif                    | Cacat implementasi                              | Perbaiki: panggil `unregister()` sebelum logout; token yatim dibersihkan otomatis |
