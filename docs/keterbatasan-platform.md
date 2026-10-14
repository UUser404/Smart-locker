# Keterbatasan Platform vs Cacat Implementasi

Dokumen ini membedakan **keterbatasan platform** (tidak bisa diperbaiki
dengan kode) dari **cacat implementasi** (bisa diperbaiki) di sistem
Smart Locker. Mengacu pada materi PBP 6 — Notification & Design Decisions.

---

## Konsep Dasar

| Aspek                | Keterbatasan Platform                                     | Cacat Implementasi                        |
| -------------------- | --------------------------------------------------------- | ----------------------------------------- |
| **Definisi**         | Batasan dari OS, browser, atau layanan pihak ketiga       | Bug dalam kode kita sendiri               |
| **Bisa diperbaiki?** | ❌ Tidak (mitigasi, bukan fix)                            | ✅ Ya                                     |
| **Tindakan**         | Dokumentasikan + mitigasi + sampaikan terbuka ke pengguna | Perbaiki kode                             |
| **Contoh**           | iOS butuh install web app ke home screen untuk notif      | Notif tidak muncul karena lupa minta izin |

---

## 1. Keterbatasan Platform (Tidak Bisa Diperbaiki)

### 1.1. FCM: Notifikasi Tertahan Saat Device Offline

**Kondisi:** HP penerima (petugas) sedang tidak terhubung internet saat
backend mengirim push notification.

**Perilaku:** FCM menyimpan pesan selama **Time to Live (TTL)**. Saat HP
kembali online, pesan dikirim. Kalau TTL lewat, pesan dibuang.

**Klasifikasi:** **Keterbatasan platform.** FCM adalah layanan pihak
ketiga (Google). Kita tidak bisa memaksa pesan sampai saat device
offline — itu di luar kendali aplikasi.

**Mitigasi di Smart Locker:**

- Set TTL 30 menit di `fcmService.js` (`android.ttl = 30 * 60 * 1000`)
- Isi notif mengandung **durasi terbuka** ("pintu terbuka sejak 5 menit
  lalu") supaya petugas tahu konteks walau telat terima
- Banner di dashboard tetap tampil saat petugas buka app

**Disampaikan ke pengguna:** di onboarding app petugas — "Notifikasi
akan sampai saat HP terhubung internet."

---

### 1.2. Android Battery Optimization Mematikan Background Service

**Kondisi:** Beberapa merek HP Android (Xiaomi, Oppo, Vivo, Huawei)
punya **aggressive battery optimization** yang mematikan app background
service setelah beberapa jam idle.

**Perilaku:** Push notification tetap sampai (via FCM service), tapi
_data message handler_ di app tidak jalan. User hanya lihat notifikasi,
tapi tidak bisa auto-refresh dashboard saat app dibuka dari notifikasi.

**Klasifikasi:** **Keterbatasan platform.** OEM memprioritaskan baterai
di atas background process.

**Mitigasi di Smart Locker:**

- App pakai **notification message + data payload** — notifikasi tetap
  tampil karena ditangani sistem operasi, bukan app
- Saat app dibuka, dashboard langsung refresh via `GET /api/admin/lockers`
- User manual disable battery optimization (opsional, di dokumentasi app)

**Disampaikan ke pengguna:** "Untuk notifikasi real-time, disable
battery optimization untuk aplikasi Smart Locker Petugas."

---

### 1.3. ESP32 di Jaringan Lokal Kampus Tidak Punya IP Publik

**Kondisi:** Backend di-hosting di Render (internet publik). ESP32 ada
di jaringan lokal kampus (di balik NAT).

**Perilaku:** Backend **tidak bisa** initiate koneksi ke ESP32. ESP32
tidak punya IP publik.

**Klasifikasi:** **Keterbatasan platform** (arsitektur jaringan).
Solusi melibatkan port forwarding (biasanya tidak diizinkan IT kampus)
atau VPN (di luar scope).

**Mitigasi di Smart Locker:**

- ESP32 **polling ke backend** (bukan sebaliknya)
- `/sync` endpoint tiap 2 detik — ESP32 inisiatif, backend hanya jawab
- Command queue: backend simpan `pendingCommand`, ESP32 ambil saat
  polling berikutnya

**Konsekuensi yang diakui:** Latensi buka locker **maksimal 2 detik**
(sesuai interval polling). Tidak bisa realtime <500ms karena keterbatasan
ini.

---

### 1.4. iOS Web Push Butuh Install ke Home Screen

**Kondisi:** User iOS (iPhone) buka web pelanggan via Safari — push
notification tidak akan sampai kecuali user install web ke home screen.

**Perilaku:** Web push di iOS **hanya bekerja** kalau:

1. iOS 16.4+
2. User sudah install web ke home screen (Add to Home Screen)
3. User izinkan notifikasi

**Klasifikasi:** **Keterbatasan platform.** Apple sengaja membatasi web
push untuk mendorong app native.

**Mitigasi di Smart Locker:**

- Web pelanggan **tidak perlu notif** — semua notif dikirim ke **app
  petugas** (Flutter Android)
- Pelanggan cukup buka web di Safari, tanpa notif
- Ini tidak jadi masalah karena scope web pelanggan tidak termasuk notif

**Disampaikan ke pengguna:** Tidak relevan (tidak ada fitur notif di web
pelanggan).

---

### 1.5. WiFi Kampus dengan Captive Portal

**Kondisi:** WiFi kampus (STTI) pakai **captive portal** — perangkat
harus login manual via halaman web sebelum dapat akses internet.

**Perilaku:** ESP32 tidak bisa login captive portal (tidak punya browser).
Koneksi HTTPS langsung di-reset oleh captive portal → error `-29312 SSL EOF`.

**Klasifikasi:** **Keterbatasan platform** (kebijakan jaringan kampus).

**Mitigasi di Smart Locker:**

- MAC address ESP32 di-whitelist oleh IT kampus → bypass captive portal
- Sudah dilakukan: MAC `F8:B3:B7:29:E3:38` berhasil whitelisted
- Alternatif: pakai hotspot HP untuk development (tidak sustainable)

**Disampaikan ke stakeholder:** "Perlu koordinasi dengan IT kampus untuk
whitelist MAC address perangkat IoT."

---

## 2. Cacat Implementasi (Sudah Diperbaiki / Bisa Diperbaiki)

### 2.1. Device Token Typo: 1 Karakter Hilang

**Kondisi:** Device token di `config.h` firmware ketik manual, 1 karakter
hilang (`f` di tengah token). Firmware dapat `401 INVALID_DEVICE_TOKEN`.

**Klasifikasi:** **Cacat implementasi.** Token harusnya di-copy persis
dari Firestore.

**Perbaikan:**

- Copy dari Firestore Console langsung
- Update `DEVICE_TOKEN` di `config.h`
- Commit + upload ulang

**Pencegahan ke depan:** Dokumentasi di `HARDWARE_WIRING_GUIDE.md`:
"Token harus di-copy, bukan diketik manual."

---

### 2.2. FCM Spam Notifikasi (Alarm Fatigue)

**Kondisi:** Setiap 30 detik, `timeoutMonitor` cek locker `occupied` dan
kirim FCM. Tanpa jeda, petugas dapat notif berulang-ulang.

**Klasifikasi:** **Cacat implementasi.** Sudah diperbaiki di Fase 6.

**Perbaikan:**

- Cooldown 10 menit per locker (`NOTIF_COOLDOWN_MS`)
- Collapse key per locker (`locker_{lockerId}`)
- TTL 30 menit
- Prioritas `high`
- Reset cooldown saat petugas resolve

**Hasil:** Notif max 1× per locker per 10 menit.

---

### 2.3. Firestore Quota Exceeded (Rotator Token)

**Kondisi:** Rotator token tulis Firestore tiap 5 detik × 4 locker =
~69.000 writes/hari. Free tier limit cuma 20.000/hari.

**Klasifikasi:** **Cacat implementasi.** Sudah diperbaiki di Fase 1.

**Perbaikan:**

- Token rotation pindah ke **in-memory** (RAM backend)
- Firestore writes untuk rotasi turun ke **~0/hari**
- Firestore tetap dipakai untuk data penting (status locker, rental)

---

### 2.4. Merge Conflict Tertinggal di `main.cpp`

**Kondisi:** Merge conflict marker (`<<<<<<<`, `=======`, `>>>>>>>`)
tidak dihapus, ter-commit ke repo. Firmware gagal compile.

**Klasifikasi:** **Cacat implementasi.**

**Perbaikan:**

- Resolve konflik manual di `main.cpp`
- Hapus semua marker + pilih kode yang benar
- Commit ulang

**Pencegahan:** Selalu cek `git status` dan compile sebelum commit.

---

### 2.5. Endpoint Debug Tertinggal di Production

**Kondisi:** Endpoint `/api/admin/debug/tokens` (untuk development) masih
ada di production. Meskipun dilindungi JWT, bukan praktik baik.

**Klasifikasi:** **Cacat implementasi.**

**Perbaikan:**

- Hapus endpoint dari `admin.js`
- Commit + deploy

---

## 3. Ringkasan Tabel

| #   | Masalah                      | Klasifikasi           | Status                                |
| --- | ---------------------------- | --------------------- | ------------------------------------- |
| 1   | FCM offline retensi (TTL)    | Keterbatasan platform | Mitigasi: TTL 30 menit                |
| 2   | Android battery optimization | Keterbatasan platform | Mitigasi: data + notification message |
| 3   | ESP32 tanpa IP publik        | Keterbatasan platform | Mitigasi: polling arsitektur          |
| 4   | iOS web push butuh install   | Keterbatasan platform | Mitigasi: tidak dipakai di scope      |
| 5   | WiFi captive portal          | Keterbatasan platform | Mitigasi: whitelist MAC               |
| 6   | Device token typo            | Cacat implementasi    | ✅ Diperbaiki                         |
| 7   | FCM spam (alarm fatigue)     | Cacat implementasi    | ✅ Diperbaiki                         |
| 8   | Firestore quota exceeded     | Cacat implementasi    | ✅ Diperbaiki                         |
| 9   | Merge conflict `main.cpp`    | Cacat implementasi    | ✅ Diperbaiki                         |
| 10  | Debug endpoint production    | Cacat implementasi    | ✅ Diperbaiki                         |

**Kesimpulan:** 5 keterbatasan platform (di-mitigasi), 5 cacat
implementasi (diperbaiki). Semua sudah ditangani atau didokumentasikan.

---

## 4. Rekomendasi untuk Stakeholder

1. **Untuk IT kampus:** whitelist MAC address perangkat IoT (sudah
   dilakukan untuk `esp32_01`).
2. **Untuk petugas:** disable battery optimization di HP Android untuk
   app Smart Locker Petugas.
3. **Untuk pengguna web:** tidak perlu notif (semua notif via app petugas).
4. **Untuk pengembangan lanjutan:** pertimbangkan VPN atau MQTT jika
   ESP32 bertambah banyak.
