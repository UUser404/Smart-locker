# Desain Notifikasi Smart Locker

Berdasarkan materi PBP 6 — Notification & Design Decisions.

## Tabel Desain Notifikasi

| Kondisi                                                       | Tingkat       | Jenis Peringatan                                                                                                                             | Persona                                    |
| :------------------------------------------------------------ | :------------ | :------------------------------------------------------------------------------------------------------------------------------------------- | :----------------------------------------- |
| Locker `needs_attention` <br>(pintu tidak tertutup > 2 menit) | **Bahaya**    | Push notification prioritas tinggi, collapse key, TTL 30 menit, cooldown 10 menit. <br>Isi: _"Locker XX — pintu terbuka sejak N menit lalu"_ | Petugas Keamanan & Kebersihan (HP Android) |
| Pintu baru terbuka <br>(transisi `closed → open`)             | **Informasi** | Banner di dashboard petugas + refresh otomatis (tidak push notif)                                                                            | Petugas                                    |
| Kode unik salah 5x dalam 10 menit                             | **Waspada**   | Banner kuning di web pelanggan + info sisa lock (tidak push notif)                                                                           | Pelanggan                                  |
| Sesi sewa selesai <br>(user pilih "Akhiri Sewa")              | **Informasi** | Tampil di riwayat + dashboard admin (tidak push notif)                                                                                       | Admin                                      |
| Kode unik berhasil dibuat <br>(user sukses rent)              | **Informasi** | Banner + salin kode di web pelanggan (tidak notif)                                                                                           | Pelanggan                                  |

## Implementasi di Backend

File: `backend-express/src/services/fcmService.js`

- **Tingkat Bahaya** → `notifyNeedsAttention()`
- **Prioritas tinggi** → `android.priority = "high"` + `apns-priority = "10"`
- **Collapse key** → `locker_{lockerId}`
- **TTL** → 30 menit (Android: `ttl = 1800000`)
- **Cooldown** → 10 menit per locker (`NOTIF_COOLDOWN_MS`)
- **Reset cooldown** → dipanggil di `/api/admin/lockers/:id/resolve`

## Skenario Demo (Video 1 Menit)

1. **Izin notifikasi** — dialog pertama, klik Izinkan
2. **Kill app + push notif** — app ditutup, notif tetap masuk
3. **Matiin data + push notif** — HP offline, notif tertahan, muncul saat online

## Keterbatasan Platform vs Cacat Implementasi

| Masalah                                                          | Klasifikasi                                     | Tindakan                                                |
| :--------------------------------------------------------------- | :---------------------------------------------- | :------------------------------------------------------ |
| Notif tidak muncul saat app di-force-stop (beberapa ROM Android) | Keterbatasan platform (beberapa OEM aggressive) | Mitigasi: background service / cek battery optimization |
| Notif tidak muncul karena lupa izin                              | Cacat implementasi                              | Perbaiki: minta izin saat fitur relevan + penjelasan    |
| Notif web di iPhone butuh install ke home screen                 | Keterbatasan platform (iOS)                     | Mitigasi: pakai app native untuk iOS (di luar scope)    |
| Notif tidak masuk saat device offline > TTL                      | Keterbatasan platform (FCM)                     | Mitigasi: set TTL 30 menit (sesuai konfigurasi)         |
