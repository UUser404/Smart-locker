# 📘 Dokumentasi Flutter — Smart Locker App (Petugas & Admin)

**Project**: `mprojectapp` — Flutter App untuk Petugas Keamanan & Admin Smart Locker
**Versi**: 1.0.0+1
**Status**: ✅ Berjalan dengan arsitektur Express sebagai single source of truth
**Terakhir Update**: 21 Oktober 2026

---

## 🎯 1. Tujuan Aplikasi

App Flutter ini adalah **dashboard internal** untuk:

1. **Petugas Keamanan** — monitor status locker secara berkala, resolve locker yang bermasalah (`needs_attention`), terima push notification FCM
2. **Admin** — lihat laporan/statistik penyewaan locker

App ini **BUKAN** untuk penyewa. Penyewa menggunakan **web** (scan QR di layar TFT locker).

---

## 🏗️ 2. Arsitektur Sistem

### Prinsip Utama

> **Express adalah single source of truth. Firestore cuma database pasif.**

```
┌──────────────┐         ┌────────────────────┐         ┌──────────────┐
│   Flutter    │──HTTP──▶│ Express (Render)   │──SDK───▶│  Firestore   │
│   (HP)       │◀─JSON──│ + JWT + bcrypt     │◀────────│ (passive DB) │
└──────────────┘         └────────────────────┘         └──────────────┘
       ▲                          ▲
       │                          │
   via FCM                    ESP32 polling
   (push notif)               (via HTTP)
```

### Aturan Arsitektur

| Aturan              | Detail                                      |
| ------------------- | ------------------------------------------- |
| Flutter → Firestore | ❌ **Tidak boleh** — diblokir total         |
| Flutter → Express   | ✅ **Satu-satunya jalur** data              |
| Express → Firestore | ✅ Pakai Admin SDK (bypass rules)           |
| Auth                | JWT via `Authorization: Bearer <token>`     |
| Update UI           | Polling 10 detik (bukan realtime)           |
| Data sensitif       | Di-mask di Express (`no_hp` → `0812****89`) |

---

## 📂 3. Struktur Folder

```
mprojectapp/
├── lib/
│   ├── main.dart                       # Entry point, startup gate
│   ├── firebase_options.dart           # Auto-generated FlutterFire
│   ├── models/
│   │   ├── locker.dart                 # Model Locker + LockerStatus enum
│   │   ├── rental_record.dart          # Model RentalRecord + RentalStats
│   │   └── session.dart                # AuthSession + UserRole enum
│   ├── screens/
│   │   ├── login_screen.dart           # Login admin/petugas
│   │   ├── dashboard_screen.dart       # Dashboard petugas (locker list)
│   │   ├── admin_home_screen.dart      # Container admin (bottom nav 2 tab)
│   │   ├── admin_analytics_screen.dart # Admin tab 1: statistik
│   │   ├── admin_history_screen.dart   # Admin tab 2: riwayat + filter
│   │   └── petugas_id_screen.dart      # (Opsional — input ID petugas)
│   ├── services/
│   │   ├── api_service.dart            # HTTP client ke Express + JWT
│   │   ├── auth_service.dart           # Login/logout + session persistence
│   │   └── fcm_service.dart            # FCM: register, unregister, stream pesan
│   ├── utils/
│   │   └── duration_formatter.dart     # Format durasi adaptif
│   ├── widgets/
│   │   └── dashboard_widgets.dart      # ProfileHeader, StatGrid, StatusBadge
│   └── theme/                          # (Kosong / belum dipakai)
└── pubspec.yaml
```

### File yang **TIDAK ADA** (sengaja dihapus)

- ❌ `lib/services/firestore_service.dart` — dihapus karena Flutter tidak akses Firestore langsung

---

## 📦 4. Dependencies (`pubspec.yaml`)

```yaml
dependencies:
  flutter:
    sdk: flutter
  http: ^1.2.0 # HTTP request ke Express
  shared_preferences: ^2.2.0 # Simpan JWT session
  firebase_core: ^3.0.0 # Firebase init (untuk FCM)
  firebase_messaging: ^15.0.0 # Push notification
  flutter_local_notifications: ^17.2.0 # Notification channel Android (alert + reminder)
  google_fonts: ^6.2.1 # Typography
  cupertino_icons: ^1.0.8
```

⚠️ **`cloud_firestore` TIDAK ada** — sengaja dihapus karena Flutter tidak akses Firestore langsung.

⚠️ **`flutter_local_notifications` WAJIB** — dipakai untuk membuat notification channel Android (`smart_locker_alert` + `smart_locker_reminder`). Tanpa package ini, reminder 1 menit memakai default channel (high priority) → bunyi tiap menit (spam). Lihat section 6.12.

---

## 🌐 5. Backend Express (Referensi)

| Item     | Nilai                                                |
| -------- | ---------------------------------------------------- |
| Base URL | `https://smart-locker-backend-a2ck.onrender.com/api` |
| Hosting  | Render.com (free tier)                               |
| Auth     | JWT expire 7 hari                                    |
| Database | Firestore project `smart-locker-project-45bac`       |

### Akun Testing

| Username   | Password     | Role    |
| ---------- | ------------ | ------- |
| `admin`    | `admin123`   | admin   |
| `petugas1` | `petugas123` | petugas |

⚠️ **Perhatikan**: `petugas1` (dengan angka), bukan `petugas`.

### Endpoint yang Dipakai Flutter

| Endpoint                     | Method | Auth           | Fungsi                                         |
| ---------------------------- | ------ | -------------- | ---------------------------------------------- |
| `/auth/login`                | POST   | ❌             | Login → return JWT                             |
| `/admin/lockers`             | GET    | ✅ JWT         | List semua locker                              |
| `/admin/lockers/:id/resolve` | POST   | ✅ JWT         | Resolve locker                                 |
| `/admin/reports/rentals`     | GET    | ✅ JWT (admin) | Laporan + statistik                            |
| `/admin/register-device`     | POST   | ❌             | Daftarkan FCM token (+ trigger catch-up notif) |
| `/admin/unregister-device`   | POST   | ✅ JWT         | Hapus FCM token saat logout                    |

---

## 📄 6. Detail File

### 6.1 `lib/main.dart`

**Fungsi**: Entry point + startup gate (cek session tersimpan).

**Alur:**

1. `Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)`
2. Daftarkan `FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler)`
3. Buat notification channel Android (`FlutterLocalNotificationsPlugin.createNotificationChannel()`) — lihat 6.12
4. `runApp(SmartLockerStaffApp)`
5. `_StartupGate` cek `AuthService.getSavedSession()`:
   - Tidak ada session → `LoginScreen`
   - Role petugas → re-register FCM + `DashboardScreen`
   - Role admin → `AdminHomeScreen`

**Key imports:**

```dart
import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'services/fcm_service.dart';
import 'screens/admin_home_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/login_screen.dart';
```

---

### 6.2 `lib/models/session.dart`

**Fungsi**: Model sesi autentikasi.

```dart
enum UserRole { admin, petugas }

class AuthSession {
  final String token;   // JWT
  final UserRole role;
  final String nama;
}
```

**Cocok dengan response login Express:**

```json
{ "token": "eyJhbGc...", "role": "admin", "nama": "Admin Smart Locker" }
```

---

### 6.3 `lib/models/locker.dart`

**Fungsi**: Model locker + enum status.

```dart
enum LockerStatus { empty, occupied, needsAttention }
```

**Field:**
| Field | Tipe | Keterangan |
|-------|------|-----------|
| `lockerId` | String | e.g. `locker_01` |
| `status` | LockerStatus | `empty` / `occupied` / `needs_attention` |
| `elapsedSeconds` | int? | Durasi terisi (dari Express) |
| `unlockedSince` | DateTime? | Waktu unlock (untuk `needs_attention`) |

**Getter derived:**

- `displayDuration` → "10m 20s", "2j 15m", dst.
- `needsAttentionSinceLabel` → "baru saja", "5 menit lalu", "2 jam lalu"

**Mapping status dari API:**
| API string | Enum |
|-----------|------|
| `empty` | `LockerStatus.empty` |
| `occupied` | `LockerStatus.occupied` |
| `needs_attention` | `LockerStatus.needsAttention` |

---

### 6.4 `lib/models/rental_record.dart`

**Fungsi**: Model riwayat sewa + statistik.

**`RentalRecord` field:**
| Field | Tipe | Keterangan |
|-------|------|-----------|
| `rentalId` | String | ID sewa |
| `lockerId` | String | Locker yang disewa |
| `nama` | String | Nama penyewa |
| `noHp` | String | No HP (**di-mask** oleh Express) |
| `startedAt` | DateTime | Waktu mulai |
| `endedAt` | DateTime? | Null jika masih aktif |
| `totalDurationSeconds` | int? | Null jika masih aktif |
| `status` | String | `active` / `completed` / `expired` |

**Getter derived:**

- `duration` → Duration?
- `displayDuration` → String ("15m", "1j 20m")

**`RentalStats` field:**
| Field | Tipe |
|-------|------|
| `totalRentals` | int |
| `avgDurationSeconds` | int |
| `busiestLockerId` | **String?** (nullable) |

**Getter derived:**

- `displayAvgDuration` → "9m 53s", "1j 5m"

---

### 6.5 `lib/services/api_service.dart` ⭐ **FILE KUNCI**

**Fungsi**: HTTP client ke Express + auto-attach JWT.

**Konstanta:**

```dart
const String kApiBaseUrl = 'https://smart-locker-backend-a2ck.onrender.com/api';
```

**Method:**
| Method | Endpoint | Return |
|--------|----------|--------|
| `login(username, password)` | POST `/auth/login` | `AuthSession` + set token internal |
| `fetchLockers()` | GET `/admin/lockers` | `List<Locker>` |
| `resolveLocker(lockerId)` | POST `/admin/lockers/:id/resolve` | `String` (new status) |
| `fetchRentalReports()` | GET `/admin/reports/rentals` | `(RentalStats, List<RentalRecord>)` |
| `registerDevice(fcmToken, petugasId)` | POST `/admin/register-device` | `void` |
| `unregisterDevice()` | POST `/admin/unregister-device` | `void` (kirim `fcm_token`, butuh JWT valid) |
| `setToken(token)` | — | — (set JWT untuk request berikutnya) |

**Fitur:**

- ✅ Auto-attach header `Authorization: Bearer <token>` jika token tersedia
- ✅ Timeout 60 detik untuk login (Render cold start), 30 detik untuk request lain
- ✅ Error handling:
  - 401 → `ApiException('Username atau password salah')` atau `'Sesi berakhir'`
  - 403 → `'Akses ditolak (bukan admin)'`
  - 404 → `'Locker tidak ditemukan'`
  - 409 → `'Locker tidak dalam status needs_attention'`
- ❌ Tidak ada `_MockBackend` — selalu hit Express asli

---

### 6.6 `lib/services/auth_service.dart`

**Fungsi**: Manage login/logout + persist JWT di `SharedPreferences`.

**Method:**
| Method | Fungsi |
|--------|--------|
| `login(username, password)` | Login + save session + set token ke `ApiService` |
| `logout()` | Hapus session + clear token |
| `getSavedSession()` | Load session dari storage + restore token ke `ApiService` |

**Storage key:** `auth_session` (di `SharedPreferences`)

**Format:** JSON string dari `AuthSession.toJson()`:

```json
{ "token": "...", "role": "admin", "nama": "Admin Smart Locker" }
```

---

### 6.7 `lib/services/fcm_service.dart`

**Fungsi**: Firebase Cloud Messaging untuk notifikasi locker bermasalah.

**Method:**
| Method | Fungsi |
|--------|--------|
| `initAndRegister(petugasId)` | Init FCM + minta izin + register token ke Express |
| `unregister()` | Hapus token dari backend, `deleteToken()` lokal, hapus `petugas_id` dari `SharedPreferences` |
| `onForegroundMessage` | Stream pesan FCM saat app aktif |
| `onMessageOpenedApp` | Stream pesan FCM saat user tap notif dari background |

**Payload FCM yang diterima** (dari `docs/API.md` 10.7):

```json
{
  "title": "Locker Perlu Perhatian",
  "body": "Locker_02 - pintu belum tertutup sejak 2 menit lalu",
  "data": { "locker_id": "locker_02", "mode": "initial" }
}
```

`data.mode` bernilai `initial` (notif awal), `reminder` (pengingat tiap 1 menit), atau `catchup` (catch-up saat login). Detail ada di `docs/API.md` 10.7.

**`unregister()` — dipanggil di `DashboardScreen._logout()` SEBELUM `authService.logout()`.** Urutan penting: unregister butuh JWT yang masih valid di `ApiService._token`. Kalau JWT expired, unregister gagal 401, tapi `deleteToken()` + hapus `petugas_id` tetap jalan → token yatim dibersihkan backend saat FCM melaporkan token invalid.

---

### 6.8 `lib/screens/login_screen.dart`

**Fungsi**: Form login username + password.

**Alur:**

1. User isi username + password
2. Validasi kosong
3. `authService.login(username, password)`
4. Kalau role petugas → `fcmService.initAndRegister(nama)`
5. Navigate ke `AdminHomeScreen` atau `DashboardScreen` berdasarkan `session.role`

**Tidak berubah** dari versi sebelumnya (sudah cocok dengan Express).

---

### 6.9 `lib/screens/dashboard_screen.dart`

**Fungsi**: Dashboard untuk role **petugas**.

**Fitur:**

- Tampil 4 kartu statistik: Kosong, Terisi, Perlu Perhatian, Total Locker
- List locker dengan status berwarna (hijau/oranye/merah)
- Tombol **Resolve** untuk locker `needs_attention`
- Pull-to-refresh
- **Polling otomatis setiap 10 detik**
- Auto-refresh saat terima notif FCM (foreground)
- Auto-refresh saat tap notif (background)
- **Catch-up snackbar**: saat `_loadLockers()` selesai, kalau ada locker `needs_attention` yang belum pernah di-snackbar pada sesi ini → tampilkan snackbar. Tracker `_snackbarShownFor` di-reset saat locker resolve.
- **Snackbar accordion**: `_showLockerSnackBar()` menutup snackbar lama untuk locker yang sama sebelum menampilkan yang baru (body di-update, tidak menumpuk). Map `_activeSnackbars` menyimpan controller per locker dan dibersihkan otomatis lewat `controller.closed`. Penutupan selalu lewat `_closeLockerSnackBar()` (try/catch), bukan `controller.close()` langsung.
- **FCM foreground**: reminder (`mode: "reminder"`) tampil snackbar oranye; notif awal (`mode: "initial"`) tampil snackbar merah.
- **Resolve**: menutup snackbar locker yang di-resolve + menghapusnya dari tracker.

**Lifecycle:**

```dart
initState:
  - _api.setToken(widget.session.token)   // ← JWT
  - _loadLockers()                         // fetch awal
  - Timer.periodic(10s, _loadLockers(silent: true))
  - Listen FCM foreground + openedApp

dispose:
  - Cancel semua timer & subscription
```

**Method:**
| Method | Fungsi |
|--------|--------|
| `_loadLockers({silent})` | Fetch dari Express. `silent=true` tidak tampilkan loading spinner |
| `_resolveLocker(locker)` | Dialog konfirmasi → POST resolve → refresh |
| `_checkCatchUpSnackbars()` | Tampilkan snackbar untuk locker `needs_attention` yang belum di-snackbar pada sesi ini |
| `_showLockerSnackBar(...)` | Tutup snackbar lama locker yang sama, lalu tampilkan yang baru |
| `_closeLockerSnackBar(lockerId)` | Tutup snackbar locker dengan aman (try/catch) — snackbar yang sudah hilang sendiri tidak membuat error |
| `_logout()` | `fcmService.unregister()` → `authService.logout()` → navigate LoginScreen |
| `_statusColor(status)` | Hijau/oranye/merah/grey |
| `_statusLabel(status)` | "Kosong"/"Terisi"/"Perlu Perhatian" |

---

### 6.10 `lib/screens/admin_home_screen.dart`

**Fungsi**: Dashboard untuk role **admin**.

**Fitur:**

- Tampil 4 kartu statistik: Total Sewa, Sedang Aktif, Rata-rata Durasi, Paling Sering
- List riwayat sewa (locker, nama, no HP ter-mask, tanggal, durasi)
- Badge "Aktif"/"Selesai"
- Pull-to-refresh
- Tombol refresh manual (tidak ada polling otomatis)

**Method:**
| Method | Fungsi |
|--------|--------|
| `_loadReports()` | Fetch dari `_api.fetchRentalReports()` |
| `_logout()` | Clear session → LoginScreen |
| `_formatDateTime(dt)` | Format `dd/MM HH:mm` |
| `_activeCount` | Getter — hitung rental yang `endedAt == null` |

---

### 6.11 `lib/widgets/dashboard_widgets.dart`

**Fungsi**: Widget reusable untuk dashboard.

| Widget          | Fungsi                                      |
| --------------- | ------------------------------------------- |
| `ProfileHeader` | Header dengan nama + role + tombol logout   |
| `StatGrid`      | Grid 2x2 untuk `StatCard`                   |
| `StatCard`      | Kartu statistik dengan icon + label + value |
| `StatusBadge`   | Badge kecil berwarna untuk status           |

---

### 6.12 Notification Channel (Android)

Dibuat sekali di `main.dart` via `FlutterLocalNotificationsPlugin.createNotificationChannel()` sebelum `runApp()`. Idempotent — aman dipanggil tiap startup.

| Channel ID              | Importance | Sound | Vibrate | Dipakai untuk                                                           |
| :---------------------- | :--------- | :---- | :------ | :---------------------------------------------------------------------- |
| `smart_locker_alert`    | High       | ✅    | ✅      | Notif awal saat locker baru jadi `needs_attention`, catch-up saat login |
| `smart_locker_reminder` | Low        | ❌    | ❌      | Reminder berkala tiap 1 menit selama locker belum di-resolve            |

**Kenapa 2 channel?**

- Notif awal harus **bunyi + getar** supaya petugas sadar.
- Reminder 1 menit **tidak boleh bunyi** — kalau bunyi terus, petugas akan mematikan notif atau mengabaikannya (alarm fatigue).
- Body reminder tetap **ter-update** (durasi bertambah) lewat `android.notification.tag` yang sama → accordion di tray (1 locker = 1 slot notif). Backend yang mengirim `tag`; `collapseKey` saja tidak cukup untuk menggantikan notif di tray.

**Verifikasi di HP**: Settings → Apps → Smart Locker Petugas → Notifications → Channels. Harus muncul 2 channel di atas.

---

## 🔐 7. Firestore Security Rules

Buka **Firebase Console → Firestore Database → Rules**, publish:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /{document=**} {
      allow read, write: if false;
    }
  }
}
```

**Kenapa aman?** Express pakai Firebase Admin SDK yang **bypass rules**. Client (Flutter) tidak bisa akses sama sekali.

---

## 🔄 8. Alur Aplikasi

### 8.1 Alur Login

```
App dibuka
    ↓
Firebase.initializeApp()
    ↓
_StartupGate cek getSavedSession()
    ├── Tidak ada → LoginScreen
    └── Ada session:
        ├── Role petugas → FCM register + DashboardScreen
        └── Role admin → AdminHomeScreen
    ↓
(User input username/password di LoginScreen)
    ↓
POST /auth/login → dapat JWT
    ↓
Simpan AuthSession di SharedPreferences
    ↓
Set token ke ApiService
    ↓
Navigate berdasarkan role
```

### 8.2 Alur Dashboard Petugas (Polling)

```
setiap 10 detik:
  GET /admin/lockers (dengan JWT)
      ↓
  Response: { lockers: [...] }
      ↓
  Update UI
```

### 8.3 Alur FCM (Notifikasi)

```
Express detect locker needs_attention
    ↓
Kirim FCM awal (channel alert, bunyi) ke semua token di petugas_devices
    ↓
Selama masih needs_attention: reminder tiap 60 detik
(channel reminder, silent, tag sama → body ter-update)
    ↓
HP terima notif
    ├── App foreground → Snackbar accordion (merah = awal, oranye = reminder) + refresh
    ├── App background → tap notif → refresh
    └── App terminated → start app → refresh
    ↓
Petugas klik Resolve → reminder berhenti
```

### 8.4 Alur Login Ulang (Catch-up) & Logout

```
Login petugas → POST /admin/register-device
    ↓
Backend (fire-and-forget): kirim FCM catch-up untuk tiap locker needs_attention
    ↓
Dashboard selesai load → _checkCatchUpSnackbars() → snackbar in-app
(petugas bisa menerima 2x: notif tray + snackbar — disengaja)

Logout → fcmService.unregister() (POST /admin/unregister-device, JWT masih valid)
    ↓
authService.logout() → hapus session lokal
```

---

## 🐛 9. Masalah yang Pernah Dihadapi & Solusinya

| Error                                                      | Penyebab                                                                                                                                                                                             | Solusi                                                                                                                           |
| ---------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------- |
| `LockerStatus.unknown` not found                           | Enum cuma 3 nilai, kode punya 4 case                                                                                                                                                                 | Hapus case `unknown`                                                                                                             |
| Gradle `Read timed out`                                    | Jaringan ke `dl.google.com` lambat                                                                                                                                                                   | Turunkan `-Xmx`, naikkan HTTP timeout di `gradle.properties`                                                                     |
| Firestore `PERMISSION_DENIED`                              | Rules belum publish                                                                                                                                                                                  | Publish rules (sementara `allow read: if true`)                                                                                  |
| `PlatformException(channel-error)`                         | Build artifacts lama masih referensi Firestore                                                                                                                                                       | **`flutter clean`** ⭐                                                                                                           |
| Login 401 di app                                           | Struktur Firestore `petugas/admin` berbeda                                                                                                                                                           | Pastikan pakai `petugas/{username}` flat                                                                                         |
| `Gagal resolve: Bad state` (tapi locker tetap jadi Kosong) | `controller.close()` dipanggil pada snackbar yang sudah hilang sendiri (duration 5 detik) → `Bad state: No element` sebelum `_loadLockers()`; juga membuat snackbar reminder foreground tidak tampil | Pakai `_closeLockerSnackBar()` (try/catch) + tracker dibersihkan via `controller.closed`                                         |
| HP bunyi tiap menit saat reminder                          | Reminder tidak memakai channel silent                                                                                                                                                                | Pastikan `flutter_local_notifications` terpasang & channel `smart_locker_reminder` (Low) terbuat; `flutter clean` lalu run ulang |

---

## 📌 10. Aturan Penting (Golden Rules)

1. **Flutter TIDAK akses Firestore.** Hanya Express yang akses.
2. **JWT auto-attach** di setiap request admin — sudah otomatis via `ApiService._headers()`.
3. **Setiap tambah/hapus dependency** di `pubspec.yaml` → WAJIB `flutter clean` + `flutter pub get` + `flutter run` (bukan hot reload).
4. **Username petugas = `petugas1`** (dengan angka), bukan `petugas`.
5. **Polling 10 detik** untuk dashboard petugas — bukan realtime.
6. **Polling manual** untuk dashboard admin (refresh button).
7. **Notif FCM** selalu trigger refresh, jangan diandalkan sebagai sumber data.
8. **`no_hp` di reports sudah ter-mask** dari Express — jangan coba un-mask di client.
9. **Jangan hardcode token** — selalu ambil dari `session.token`.
10. **Setiap perubahan endpoint**, update `docs/API.md` dulu (kontrak resmi).
11. **Unregister FCM WAJIB saat logout** — panggil `fcmService.unregister()` SEBELUM `authService.logout()`. Kalau terbalik, JWT sudah tidak valid → unregister 401.
12. **Reminder pakai channel berbeda** — `smart_locker_alert` (bunyi) untuk notif awal, `smart_locker_reminder` (silent) untuk reminder. Jangan campur — kalau reminder pakai channel alert, HP bunyi tiap menit.
13. **Snackbar accordion** — tutup snackbar lama untuk locker yang sama lewat `_closeLockerSnackBar(lockerId)` sebelum show baru. **Jangan** panggil `controller.close()` langsung: snackbar hanya tampil 5 detik, dan `close()` pada snackbar yang sudah hilang melempar `Bad state: No element` di mode debug.
14. **`_snackbarShownFor` reset saat resolve** — kalau tidak, snackbar catch-up tidak muncul lagi setelah locker resolve lalu `needs_attention` lagi pada sesi yang sama.

---

## 🧪 11. Checklist Testing

| #   | Test                                                          | Expected                                                  |
| --- | ------------------------------------------------------------- | --------------------------------------------------------- |
| 1   | Login petugas (`petugas1`/`petugas123`)                       | Dashboard petugas muncul                                  |
| 2   | Edit Firestore `lockers/locker_01.status` → `needs_attention` | UI update ~10 detik                                       |
| 3   | Klik "Resolve"                                                | Status balik `empty` di Firestore                         |
| 4   | Login admin (`admin`/`admin123`)                              | Statistik + list rental muncul, no_hp ter-mask            |
| 5   | Cek `petugas_devices` di Firestore                            | Ada document setelah login petugas                        |
| 6   | Trigger needs_attention di Firestore                          | FCM push masuk ≤ 30 detik                                 |
| 7   | Logout → login ulang                                          | Session persist, tidak perlu login ulang saat app restart |
| 8   | Kill app → buka lagi                                          | Auto-login jika session belum expired (7 hari)            |
| 9   | Reminder, catch-up, unregister, channel (Fase 7)              | Lihat tabel test di `DOKUMENTASI_PROGRESS.md` section 9   |

---

## 🛠️ 12. Cara Build & Deploy

### Development

```bash
cd mprojectapp
flutter pub get
flutter run
```

### Kalau ada error setelah ubah dependency

```bash
flutter clean
flutter pub get
flutter run   # full restart
```

### Build APK Release

```bash
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk
```

### Build App Bundle (Play Store)

```bash
flutter build appbundle --release
```

---

## 📚 13. Referensi

| Dokumen                | Lokasi                                     |
| ---------------------- | ------------------------------------------ |
| Kontrak API            | `docs/API.md`                              |
| Progress backend Galuh | `firmware/DOKUMENTASI_PROGRESS_BACKEND.md` |
| SKPL                   | `docs/SKPL Smart Locker IoT-final.docx`    |
| DEVELOPMENT_GUIDE      | `docs/DEVELOPMENT_GUIDE.md`                |

| Resource           | URL                                                                      |
| ------------------ | ------------------------------------------------------------------------ |
| Repo GitHub        | `github.com/User404/Smart-locker`                                        |
| Production Backend | `https://smart-locker-backend-a2ck.onrender.com`                         |
| Dashboard Render   | `https://dashboard.render.com`                                           |
| Firebase Console   | `https://console.firebase.google.com/project/smart-locker-project-45bac` |

---

## 🛣️ 14. Roadmap Selanjutnya

### A. Render Anti-Sleep (Recommended)

Render free tier auto-sleep setelah 15 menit idle → cold start 30-50 detik.
**Solusi**: cron-job.org ping `https://smart-locker-backend-a2ck.onrender.com/api/...` tiap 10 menit.

### B. Production Hardening

- Ganti password default `admin123` / `petugas123`
- Verifikasi `JWT_SECRET` di Render (random 48 chars)
- Audit Firestore Rules publish

### C. UX Improvements

- 401 (token expired) → auto-redirect ke login
- Network error → retry button
- Cold start → loading indicator "Menyambungkan server..."

### D. Integrasi Firmware ESP32

- ESP32 polling `/api/firmware/esp32_01/poll` tiap 2 detik
- Sensor pintu lapor closed → sesi finalisasi

### E. Web Dashboard (Opsional)

Untuk admin yang butuh tampilan lebih besar dari HP.

---

## ✅ 15. Checklist Serah Terima

- [x] Login Express (JWT + bcrypt)
- [x] List lockers via Express
- [x] Resolve locker via Express
- [x] Reports rentals via Express
- [x] Register FCM device via Express
- [ ] Unregister FCM device via Express (saat logout) — kode selesai, belum teruji
- [ ] Reminder berkala 1 menit (accordion) — kode selesai, masih debugging (belum muncul pada uji 21 Okt)
- [ ] Catch-up notif saat login — kode selesai, belum teruji
- [ ] 2 notification channel (alert + reminder) — kode selesai, belum diverifikasi di Settings HP
- [x] `no_hp` di-mask otomatis di backend
- [x] Firestore Rules dikunci total
- [x] Tidak ada akses Firestore dari Flutter
- [x] `cloud_firestore` dihapus dari Flutter
- [x] Polling 10 detik untuk petugas
- [x] FCM notifikasi end-to-end
- [ ] Render anti-sleep cron job
- [ ] Production password change
- [ ] Firmware ESP32
- [ ] Merge ke `main`

---

**Dokumentasi ini bagian dari seri**:

1. `DOKUMENTASI_PROGRESS_BACKEND.md` — Sisi Express + Firestore (Galuh)
2. `DOKUMENTASI_FLUTTER.md` (dokumen ini) — Sisi App Petugas & Admin
3. `docs/API.md` — Kontrak resmi endpoint

**Arsitektur final**: Express = single source of truth, Firestore = passive DB, Flutter = thin client, ESP32 = polling executor. 🎯
