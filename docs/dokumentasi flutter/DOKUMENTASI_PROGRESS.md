# Dokumentasi Progress — Smart Locker: App Petugas (Flutter)

> Dokumen ini merangkum apa yang sudah dikerjakan untuk sisi **app Flutter
> petugas** dan **web pelanggan** dari project Smart Locker IoT, dari awal
> sampai sesi kerja terakhir. Simpan sebagai catatan lanjutan untuk sesi
> berikutnya.

---

## 1. Ringkasan Proyek

Smart Locker: sistem penyewaan locker otomatis berbasis scan barcode,
tanpa akun permanen. Ada 2 sisi:

- **Sisi pelanggan** — sepenuhnya web (dikerjakan user, belum dimulai per dokumen ini)
- **Sisi Petugas Keamanan & Kebersihan** — app Flutter Android (dikerjakan user, progress dijelaskan di bawah)

Alur inti: user scan barcode → isi nama & no HP → dapat kode unik 1x-lihat →
locker terbuka → sensor magnet auto-lock saat pintu ditutup → sesi model
"parkir" (durasi dihitung, bukan ditentukan di awal). Kalau pintu tidak
tertutup dalam 2 menit, backend menandai locker `needs_attention` dan
mengirim push notification ke app petugas.

Dokumen sumber lengkap (sudah ada sebelumnya, tidak diulang di sini):
- `docs/API.md` — kontrak resmi endpoint (backend ↔ firmware ↔ web ↔ app petugas)
- `DEVELOPMENT_GUIDE.md` — konsep, 5W1H, arsitektur, RAB, alur pengerjaan

**Peran user di project ini:** membangun web pelanggan dan app Flutter
Android untuk Petugas Keamanan & Kebersihan.

---

## 2. Endpoint yang Dipakai App Petugas

Sesuai `docs/API.md` bagian 10, app Flutter cuma konsumsi 3 endpoint:

| Endpoint | Method | Fungsi |
|---|---|---|
| `/api/admin/lockers` | GET | List semua locker + status, untuk dashboard |
| `/api/admin/lockers/{locker_id}/resolve` | POST | Tandai locker `needs_attention` kembali jadi `empty` |
| `/api/admin/register-device` | POST | Daftarkan token FCM device petugas (dipanggil sekali di awal) |

Push notification dikirim **backend → app** lewat FCM saat locker jadi
`needs_attention` (bukan app yang polling untuk ini).

---

## 3. Struktur Kode yang Sudah Dibuat

```
lib/
├── main.dart                       # entry point, init Firebase, routing awal
├── models/
│   └── locker.dart                 # model Locker + enum LockerStatus
├── services/
│   ├── api_service.dart            # HTTP client ke 3 endpoint di atas
│   └── fcm_service.dart            # setup permission, token FCM, register ke backend
└── screens/
    ├── petugas_id_screen.dart      # input nama/NIP sekali (belum ada login penuh)
    └── dashboard_screen.dart       # list locker, tombol resolve, listener push
```

### Detail tiap file

**`models/locker.dart`**
Model `Locker` dengan `LockerStatus` enum (`empty`, `occupied`,
`needsAttention`, `unknown`). Punya helper `displayDuration` (format durasi
occupied jadi "Xj Ym Zd") dan `needsAttentionSince` (format relatif, mis.
"7 menit lalu").

**`services/api_service.dart`**
- Konstanta `kApiBaseUrl` — placeholder `https://<domain-backend>/api`, **belum diisi** karena backend belum ada.
- Konstanta `kUseMockData = true` — **saat ini aktif**. Semua fungsi (`fetchLockers`, `resolveLocker`, `registerDevice`) dialihkan ke `_MockBackend` in-memory, tidak ada HTTP request sama sekali.
- `_MockBackend` menyimpan 4 locker dummy (`locker_01`–`04`) dengan campuran status `empty`/`occupied`/`needsAttention`, durasi occupied nambah otomatis tiap `fetchLockers()` dipanggil, dan `resolveLocker()` beneran mengubah state locker jadi `empty`.
- **Cara balik ke backend asli nanti:** set `kUseMockData = false`, isi `kApiBaseUrl` dengan domain asli.

**`services/fcm_service.dart`**
- `initAndRegister(petugasId)` — minta permission notifikasi, ambil token FCM, panggil `registerDevice`, dan auto re-register kalau token berubah (`onTokenRefresh`).
- Simpan `petugasId` di `SharedPreferences` lokal (key: `petugas_id`) supaya tidak perlu isi ulang tiap buka app.
- `firebaseMessagingBackgroundHandler` — top-level function wajib untuk handle push saat app di-background/terminated (didaftarkan di `main.dart`).
- Expose `onForegroundMessage` dan `onMessageOpenedApp` sebagai stream untuk didengarkan `DashboardScreen`.

**`screens/petugas_id_screen.dart`**
Form sederhana: input nama/NIP → panggil `fcmService.initAndRegister()` →
kalau sukses, pindah ke `DashboardScreen`. Ini dipakai karena dokumen
menyebutkan prototipe belum pakai login/PIN staf penuh.

**`screens/dashboard_screen.dart`**
- `GET /admin/lockers` saat pertama buka + auto-refresh tiap 10 detik (`Timer.periodic`) + refresh tambahan tiap ada push masuk (foreground atau tap notifikasi).
- List locker dengan warna status (hijau/oranye/merah) dan info durasi/waktu needs_attention.
- Tombol **Resolve** cuma muncul untuk locker `needsAttention`, dengan dialog konfirmasi sebelum manggil `resolveLocker()`.

**`main.dart`**
- `Firebase.initializeApp()` + daftar `firebaseMessagingBackgroundHandler` sebelum `runApp()`.
- `_StartupGate`: cek apakah `petugas_id` sudah tersimpan lokal — kalau sudah, langsung re-register token & masuk `DashboardScreen`; kalau belum, ke `PetugasIdScreen`.
- **Butuh** file `firebase_options.dart` di folder yang sama (di-generate `flutterfire configure`, sudah dijalankan — lihat bagian 4).

---

## 4. Log Setup & Troubleshooting (Kronologis)

Ini histori masalah yang sudah ditemui & solusinya, biar tidak perlu
mengulang riset kalau ketemu masalah serupa lagi:

1. **`flutter pub get`** — dependency (`firebase_core`, `firebase_messaging`, `http`, `shared_preferences`) berhasil terpasang. Muncul warning "Building with plugins requires symlink support" karena Windows butuh **Developer Mode** aktif → diaktifkan lewat Settings → Privacy & security → For developers.
2. **`flutterfire` command not found** — karena `dart pub global activate flutterfire_cli` menaruh binary di `%LOCALAPPDATA%\Pub\Cache\bin`, yang belum ada di PATH. Solusi sementara: panggil lewat path lengkap, `& "$env:LOCALAPPDATA\Pub\Cache\bin\flutterfire.bat" configure`. Solusi permanen: tambahkan folder itu ke PATH via Environment Variables, lalu buka terminal baru.
3. **Firebase CLI belum terinstall** — `flutterfire configure` butuh `firebase` CLI resmi (Node.js package terpisah). Diinstall lewat `npm install -g firebase-tools`, lalu `firebase login`.
4. **Timeout + "Failed to authenticate"** saat `firebase projects:create` — sesi login kepakai gak valid. **Catatan penting:** command `logout`/`login`/`login:list` itu milik **`firebase` CLI**, bukan `flutterfire` — sempat salah panggil `flutterfire logout` yang error karena command itu tidak ada di situ. Solusi: `firebase logout` → `firebase login` (pakai `--no-localhost` kalau browser gagal redirect balik).
5. **"Failed to add Firebase to Google Cloud Platform project"** saat create project baru lewat CLI — solusinya bikin project manual dulu lewat [console.firebase.google.com](https://console.firebase.google.com), baru pilih project itu di `flutterfire configure` (tanpa opsi create-new).
6. **`flutterfire configure` masih "Found 0 Firebase projects"** meski project sudah dibuat di console — penyebabnya akun yang login di CLI (`firebase login:list`) beda dengan akun yang dipakai bikin project di browser. Setelah disamakan akunnya, berhasil.
7. **`flutterfire configure` akhirnya berhasil** — file `firebase_options.dart` sudah ter-generate.
8. **Backend belum ada** (masih tahap prototipe) — diputuskan pakai **mock data in-memory** di `api_service.dart` (`kUseMockData = true`) supaya UI tetap bisa didemo/dites tanpa nunggu backend. Detail lihat bagian 3.
9. **`AndroidManifest.xml`** — ditambahkan `<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />` sebagai *sibling* dari `<application>`, bukan di dalamnya, untuk dukungan permission notifikasi Android 13+.

---

## 5. Status Saat Ini

- [x] Struktur kode Flutter app petugas lengkap (5 file di `lib/`)
- [x] Dependency terpasang (`pubspec.yaml`)
- [x] `flutterfire configure` berhasil, `firebase_options.dart` ada
- [x] `AndroidManifest.xml` sudah ditambah permission notifikasi
- [x] Mode mock data aktif untuk demo tanpa backend
- [ ] **Belum ditest jalan** — user belum punya emulator, dan belum sempat coba run di device fisik
- [ ] Backend asli belum dibangun (masih di luar scope sesi ini)
- [ ] `kApiBaseUrl` masih placeholder, perlu diisi kalau backend sudah ada
- [ ] Web pelanggan belum dimulai sama sekali

---

## 6. Langkah Selanjutnya (Belum Dikerjakan)

1. **Test app** — karena belum ada emulator, opsinya:
   - Colok HP Android fisik (aktifkan USB debugging di Developer Options), lalu `flutter run`
   - Atau install emulator lewat Android Studio (AVD Manager) kalau mau tanpa device fisik
2. Kalau app berhasil jalan dengan mock data, verifikasi alur: `PetugasIdScreen` → izin notifikasi → `DashboardScreen` tampil 4 locker dummy → tombol Resolve mengubah status locker_03 jadi kosong.
3. Setelah app dari sisi UI beres, mulai kerjakan **web pelanggan** (belum ada progress sama sekali): halaman hasil scan barcode yang render 3 kondisi (`empty`/`occupied`/`needs_attention`) sesuai endpoint 1–4 di `docs/API.md`.
4. Backend asli (di luar scope user langsung, tapi jadi blocker untuk `kUseMockData = false`) — kalau backend sudah mulai dibangun pihak lain, koordinasikan domain/URL untuk diisi ke `kApiBaseUrl`.
