# Dokumentasi Progress — Smart Locker: App Petugas & Admin (Flutter)

> Dokumen ini merangkum apa yang sudah dikerjakan untuk sisi **app Flutter petugas & admin** dan **web pelanggan** dari project Smart Locker IoT, dari awal sampai sesi kerja terakhir (14 Oktober 2026).

---

## 1. Ringkasan Proyek

**Smart Locker**: sistem penyewaan locker otomatis berbasis scan QR dinamis, tanpa akun permanen.

Ada 2 sisi:

- **Sisi pelanggan** — sepenuhnya web (HTML/CSS/JS statis), tanpa install apa pun.
- **Sisi Petugas Keamanan & Kebersihan** — app Flutter Android untuk dashboard, resolve, dan push notification.

**Alur inti**:
User scan QR di layar locker → isi nama & no HP → dapat kode unik 1x lihat → locker terbuka → sensor magnet auto-lock saat pintu ditutup → sesi model "parkir" (durasi dihitung, bukan ditentukan di awal). Kalau pintu tidak tertutup dalam 2 menit, backend menandai locker `needs_attention` dan mengirim push notification ke app petugas.

**Dokumen sumber lengkap**:

- `docs/API.md` — kontrak resmi endpoint (backend ↔ firmware ↔ web ↔ app)
- `docs/DEVELOPMENT_GUIDE.md` — konsep, 5W1H, arsitektur, RAB
- `docs/DOKUMENTASI_TESTING_FCM.md` — testing FCM end-to-end (14 Okt 2026)
- `firmware/DOKUMENTASI_PROGRESS_BACKEND.md` — progress backend Express (Galuh)

**Peran user di project ini**: membangun web pelanggan dan app Flutter Android untuk Petugas Keamanan & Kebersihan.

---

## 2. Update Progress — 14 Oktober 2026

| Komponen                    |          Status          | Detail                               |
| --------------------------- | :----------------------: | ------------------------------------ |
| Backend Express (Batch 1-5) |      ✅ **Selesai**      | Live di Render.com                   |
| Login & Auth (JWT)          |      ✅ **Selesai**      | bcrypt + JWT 7 hari                  |
| Dashboard Petugas           |      ✅ **Selesai**      | List locker, resolve, auto-refresh   |
| Dashboard Admin             |      ✅ **Selesai**      | 2 tab: Analitik + Riwayat            |
| FCM Notification            | ✅ **Teruji end-to-end** | Notif masuk ke HP petugas            |
| Durasi Adaptif              |      ✅ **Selesai**      | Format "5h 8j" untuk rental panjang  |
| Auto-Refresh (Resume)       |      ✅ **Selesai**      | `WidgetsBindingObserver`             |
| FCM Terminated Handling     |      ✅ **Selesai**      | `getInitialMessage()`                |
| Web Pelanggan               |    ⏳ **In Progress**    | HTML/CSS/JS statis, perlu verifikasi |
| Integrasi fisik (hardware)  |    ⏳ **In Progress**    | Menunggu rakitan dari Alfian         |

---

## 3. Endpoint yang Dipakai App

Sesuai `docs/API.md`, app Flutter konsumsi endpoint berikut:

### Endpoint Publik

| Endpoint                     | Method | Fungsi                           |
| ---------------------------- | ------ | -------------------------------- |
| `/api/auth/login`            | POST   | Login petugas/admin → JWT        |
| `/api/admin/register-device` | POST   | Daftarkan FCM token (tanpa auth) |

### Endpoint Admin/Petugas (JWT required)

| Endpoint                          | Method | Role           | Fungsi                                    |
| --------------------------------- | ------ | -------------- | ----------------------------------------- |
| `/api/admin/lockers`              | GET    | admin, petugas | List locker + status untuk dashboard      |
| `/api/admin/lockers/{id}/resolve` | POST   | admin, petugas | Tandai locker `needs_attention` → `empty` |
| `/api/admin/reports/rentals`      | GET    | **admin only** | Laporan rentals + statistik               |

> **Push notification** dikirim **backend → app** lewat FCM saat locker jadi `needs_attention` (bukan app yang polling untuk ini).
>
> **Base URL production**: `https://smart-locker-backend-a2ck.onrender.com/api`

---

## 4. Struktur Kode

```text
mprojectapp/lib/
├── main.dart                  # Entry point, startup gate
├── firebase_options.dart      # Auto-generated FlutterFire
│
├── models/
│   ├── locker.dart            # Locker + LockerStatus enum
│   ├── rental_record.dart     # RentalRecord + RentalStats
│   └── session.dart           # AuthSession + UserRole
│
├── services/
│   ├── api_service.dart       # HTTP client ke Express + JWT
│   ├── auth_service.dart      # Login/logout + session persist
│   └── fcm_service.dart       # Firebase Cloud Messaging
│
├── screens/
│   ├── login_screen.dart      # Form login username/password
│   ├── dashboard_screen.dart  # Dashboard Petugas (locker list)
│   ├── admin_home_screen.dart # Container Admin (bottom nav)
│   ├── admin_analytics_screen.dart # Tab 1: statistik
│   ├── admin_history_screen.dart   # Tab 2: riwayat + filter
│   └── petugas_id_screen.dart # (Legacy) input nama/NIP
│
├── utils/
│   └── duration_formatter.dart # Format adaptif "5h 8j"
│
└── widgets/
    └── dashboard_widgets.dart # ProfileHeader, StatGrid, dll
```

### Detail Tiap File

- **`main.dart`**: `Firebase.initializeApp()` + daftar `firebaseMessagingBackgroundHandler` sebelum `runApp()`. `_StartupGate`: cek `AuthService.getSavedSession()`. Tidak ada session → `LoginScreen`. Role petugas → re-register FCM + `DashboardScreen`. Role admin → `AdminHomeScreen`.
- **`models/locker.dart`**: Model `Locker` dengan `LockerStatus` enum (`empty`, `occupied`, `needsAttention`). Helper `displayDuration` — format adaptif: < 1 menit "45s", < 1 jam "5m 20s", < 1 hari "2j 15m", < 30 hari "5h 8j", >= 30 hari "1bl 12j". Helper `needsAttentionSinceLabel` — format relatif, mis. "7 menit lalu".
- **`models/rental_record.dart`**: Model `RentalRecord` + `RentalStats`. `busiestLockerId` nullable (backend kadang kirim null). Helper `displayDuration` — pakai `duration_formatter.dart` yang sama.
- **`models/session.dart`**: `AuthSession` dengan `token`, `role`, `nama`. `UserRole` enum (`admin`, `petugas`).
- **`services/api_service.dart`**: `kApiBaseUrl = 'https://smart-locker-backend-a2ck.onrender.com/api'`. Tidak ada mock data — selalu hit Express asli. `_token` di-set setelah login, auto-attach ke header `Authorization: Bearer`.
- **`services/auth_service.dart`**: Login → simpan session + set token ke `ApiService`. Logout → hapus session + clear token. `getSavedSession()` → restore session + re-set token. Key: `auth_session` (di `SharedPreferences`).
- **`services/fcm_service.dart`**: `initAndRegister(petugasId)`: request permission, ambil token FCM, POST ke `/admin/register-device`. Bind `onTokenRefresh` sekali saja (static flag). `firebaseMessagingBackgroundHandler` — top-level function. Expose stream `onForegroundMessage` + `onMessageOpenedApp`.
- **`utils/duration_formatter.dart`**: Helper `formatDuration(Duration d)` — logika: >= 30 hari → "Xbl Yj", >= 1 hari → "Xh Yj", >= 1 jam → "Xj Ym", >= 1 menit → "Xm Ys", < 1 menit → "Xs".
- **`screens/login_screen.dart`**: Form username + password. Panggil `AuthService.login()`. Kalau role petugas → `fcmService.initAndRegister(nama)`. Navigate berdasarkan role.
- **`screens/dashboard_screen.dart` (Petugas)**: Polling 10 detik via `Timer.periodic`. Auto-refresh saat app resume (via `WidgetsBindingObserver`, throttle 30s). FCM terminated handling via `getInitialMessage()`. List locker dengan warna status (Hijau/Oranye/Merah) + tombol Resolve (dialog konfirmasi → POST ke Express → refresh).
- **`screens/admin_home_screen.dart`**: Bottom navigation dengan 2 tab. Data di-fetch sekali di parent. `IndexedStack` untuk keep-alive. `WidgetsBindingObserver` untuk auto-refresh saat resume.
- **`screens/admin_analytics_screen.dart` (Tab 1)**: Kartu statistik (Total Sewa, Sedang Aktif, Rata-rata Durasi, Paling Sering), Status Locker overview, Status Sewa, Top 3 Locker.
- **`screens/admin_history_screen.dart` (Tab 2)**: Filter chips (**Semua / Aktif / Selesai** dengan count), list riwayat rental dengan badge status, durasi terformat, no HP ter-mask dari backend, pull-to-refresh.
- **`screens/petugas_id_screen.dart`**: Legacy (tidak dipakai lagi, login pakai JWT Express).

---

## 5. Fitur yang Sudah Berfungsi

### Auth & Session

- ✅ Login via Express (bcrypt verify)
- ✅ Session persist di `SharedPreferences`
- ✅ Auto-login saat app dibuka
- ✅ Logout clear session + token

### Dashboard Petugas

- ✅ List 4 locker dari Express
- ✅ Polling 10 detik & auto-refresh saat app resume (throttle 30s)
- ✅ Statistik count: Kosong / Terisi / Perhatian
- ✅ Resolve locker via tombol + dialog
- ✅ Error handling (401, 409, timeout) & pull-to-refresh

### Dashboard Admin

- ✅ 2 tab: Analitik + Riwayat (bottom nav)
- ✅ Statistik rentals & status locker overview
- ✅ Riwayat rentals dengan filter chips & no HP ter-mask otomatis

### FCM Notification

- ✅ Register token saat login petugas & auto re-register saat token refresh
- ✅ **Foreground** → snackbar + refresh
- ✅ **Background & Terminated** → notif di system tray, tap → buka app + refresh
- ✅ **Teruji end-to-end** (lihat `docs/DOKUMENTASI_TESTING_FCM.md`)

### UI/UX

- ✅ Durasi adaptif ("5h 8j" untuk rental panjang)
- ✅ Warna status konsisten (hijau/oranye/merah)
- ✅ Material Design 3, loading state, empty state, error state

---

## 6. Log Setup & Troubleshooting (Kronologis)

1. **Setup Awal**: `flutter pub get`. Warning symlink di Windows diatasi dengan aktifkan **Developer Mode** di Settings.
2. **Flutterfire & Firebase CLI**: Instalasi Firebase CLI via npm, login, dan konfigurasi project manual via web console jika timeout.
3. **Migrasi Mock → Express**:
   - `LockerStatus.unknown` dihapus (enum cuma 3: `empty`, `occupied`, `needsAttention`).
   - Gradle `Read timed out` diatasi dengan turunkan `-Xmx` di `gradle.properties`.
   - Firestore `PERMISSION_DENIED` diatasi dengan publish rules.
   - `PlatformException` diatasi dengan `flutter clean`.
4. **Arsitektur Final**: Express = single source of truth. Flutter tidak akses Firestore langsung. Firestore Rules dikunci total (`allow read, write: if false`). JWT auto-attach di setiap request admin.
5. **FCM**:
   - Token dummy dibersihkan dari `petugas_devices`.
   - Pengujian harus mensimulasikan state `occupied` + `unlockedSince` (bukan set `needs_attention` manual).

---

## 7. Status Saat Ini

### Sudah Selesai ✅

- [x] Struktur kode Flutter lengkap (11 file di `lib/`)
- [x] Dependency terpasang (`http`, `shared_preferences`, `firebase_core`, `firebase_messaging`, `google_fonts`)
- [x] `firebase_options.dart` ada
- [x] Login via Express (JWT + bcrypt)
- [x] Dashboard petugas (polling 10 detik, resolve)
- [x] Dashboard admin (2 tab: Analitik + Riwayat)
- [x] Statistik admin & riwayat rentals dengan filter
- [x] Durasi adaptif (`duration_formatter.dart`)
- [x] Auto-refresh saat app resume & FCM lengkap (foreground, background, terminated)
- [x] **FCM teruji end-to-end**
- [x] AndroidManifest.xml sudah ditambah permission notifikasi

### Belum Selesai ⏳

- [ ] **Web pelanggan** — HTML/CSS/JS statis di `mprojectapp/web/public/`, perlu verifikasi fungsional
- [ ] **Render anti-sleep** — cron ping untuk demo smooth
- [ ] **Integrasi fisik** — rakitan hardware (menunggu Alfian)
- [ ] **Production hardening** — ganti password default, audit rules

---

## 8. Langkah Selanjutnya

### Prioritas Tinggi

1. **Setup Render anti-sleep** — pakai cron-job.org ping tiap 10 menit supaya tidak cold start 30-60 detik.
2. **Verifikasi web pelanggan** — cek `mprojectapp/web/public/index.html` sudah bisa scan QR + sewa atau belum.
3. **Update dokumentasi backend** — sinkron `docs/API.md` dengan implementation terbaru.
4. **Production hardening**: ganti password default, verifikasi `JWT_SECRET` di Render, audit Firestore Rules.

### Prioritas Sedang

5. **Testing skenario tambahan**: FCM saat app background/minimize/terminated, multiple petugas, deep link notif.
6. **Web pelanggan**: halaman scan browser, form sewa, kode unik & tombol copy, input kode unik.

### Prioritas Rendah

7. **Polish UI**: dark mode, animasi transisi, grafik analitik.
8. **Fitur tambahan**: export CSV riwayat, filter tanggal di reports, multi-bahasa.

---

## 9. Cara Test

### Backend Express

```bash
# Health check
curl https://smart-locker-backend-a2ck.onrender.com/

# Login
curl -X POST https://smart-locker-backend-a2ck.onrender.com/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"admin123"}'
```

### Flutter App

```bash
cd mprojectapp
flutter clean
flutter pub get
flutter run
```

### Test FCM

Ikuti step di `docs/DOKUMENTASI_TESTING_FCM.md`:

1. Login petugas di HP
2. Set `lockers/locker_02`: `status: "occupied"` + `unlockedSince: 3 menit lalu`
3. Tunggu 30-60 detik
4. Cek notif di HP + log di Render

---

## 10. Referensi

| File                                       | Deskripsi                                            |
| ------------------------------------------ | ---------------------------------------------------- |
| `lib/main.dart`                            | Entry point + startup gate                           |
| `lib/models/*.dart`                        | Model Locker, RentalRecord, AuthSession              |
| `lib/services/*.dart`                      | ApiService, AuthService, FcmService                  |
| `lib/screens/*.dart`                       | Login, Dashboard (petugas), Admin (analitik+riwayat) |
| `lib/utils/duration_formatter.dart`        | Format durasi adaptif                                |
| `lib/widgets/dashboard_widgets.dart`       | Widget reusable                                      |
| `docs/API.md`                              | Kontrak resmi endpoint                               |
| `docs/DOKUMENTASI_TESTING_FCM.md`          | Testing FCM end-to-end                               |
| `firmware/DOKUMENTASI_PROGRESS_BACKEND.md` | Progress backend (Galuh)                             |

---

## 11. Akun Testing

| Username   | Password     | Role      |
| ---------- | ------------ | --------- |
| `admin`    | `admin123`   | `admin`   |
| `petugas1` | `petugas123` | `petugas` |

⚠️ _Ganti password ini sebelum demo production!_
