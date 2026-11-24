# Smart Locker Design System v1.0

Satu tema untuk semua role (Pelanggan, Petugas, Admin) dan semua platform (web, Android, Flutter Web). Semua nilai visual berasal dari satu file: `tokens/tokens.json`. Jangan menulis warna, ukuran, atau radius langsung di kode atau Figma; selalu pakai token.

## 1. Prinsip

1. **Status dulu.** Hal yang butuh tindakan selalu tampil paling atas dan paling menonjol.
2. **Satu bahasa status.** Kosong, Disewa, Perhatian, Offline memakai warna, label, dan urutan yang sama di semua layar.
3. **Warna tidak sendirian.** Setiap status punya label teks, jadi tetap terbaca di bawah sinar matahari dan bagi pengguna buta warna.
4. **Aksi berdampak diberi pengaman.** Resolve butuh syarat terpenuhi, buka darurat butuh alasan dan tahan 2 detik. Semuanya tercatat atas nama pelaku.
5. **Sembunyikan yang teknis.** Relay, solenoid, dan indeks hanya di "Info teknis". Yang selalu terlihat: status, penyewa, durasi, dan koneksi ESP32 masing-masing locker.
6. **Privasi bertingkat.** Nomor telepon tampil tersamar (`0812****7890`) di semua role. Nomor penuh hanya untuk Admin dan setiap pembukaan dicatat di Log Audit.

## 2. Token

Sumber: `tokens/tokens.json`. Hasil generate: `tokens.css`, `tokens.figma.json`, `flutter/app_tokens.dart`.

### Warna

| Kelompok | Token | Nilai | Fungsi |
|---|---|---|---|
| Brand | `brand.primary` | `#1D4ED8` | Aksi utama, tab aktif, tautan |
| | `brand.primaryContainer` | `#DBEAFE` | Latar item navigasi aktif |
| Netral | `neutral.bg` | `#F5F7FA` | Latar halaman |
| | `neutral.surface` / `surfaceMuted` | `#FFFFFF` / `#F8FAFC` | Kartu / header tabel |
| | `neutral.fillMuted` | `#F1F5F9` | Chip tidak aktif, pemisah halus |
| | `neutral.border` / `borderStrong` | `#E2E8F0` / `#CBD5E1` | Garis kartu / tombol outline |
| | `neutral.ink` | `#0F172A` | Teks utama |
| | `neutral.textBody` / `textMuted` / `textDisabled` | `#475569` / `#64748B` / `#94A3B8` | Teks isi / sekunder / nonaktif |
| | `neutral.inverse` / `inverseRaised` | `#0F172A` / `#1E293B` | Sidebar admin web |
| Status | `success.*` | main `#16A34A` | Kosong, berhasil, online |
| | `info.*` | main `#2563EB` | Disewa, berjalan |
| | `warning.*` | main `#EA580C` | Perhatian |
| | `danger.*` | main `#DC2626` | Offline, buka darurat, gagal |

Setiap kelompok status punya enam turunan: `main` (titik, angka besar, tombol solid), `container` (latar badge), `tint` (latar kartu), `border`, `text` (teks di atas container), `strong` (angka hero).

### Pemetaan status locker

| State | Kelompok warna | Label |
|---|---|---|
| kosong | success | KOSONG |
| disewa | info | DISEWA |
| perhatian | warning | PERHATIAN |
| offline, darurat | danger | OFFLINE / BUKA DARURAT |

Di Flutter: `AppStatus.of(LockerState.perhatian)`. Di CSS: `var(--state-perhatian-main)`.

### Tipografi (Inter)

| Token | Ukuran / berat | Pemakaian |
|---|---|---|
| `display` | 40 / 800 | Timer hero (06:12) |
| `headline` | 22 / 800 | Judul halaman mobile |
| `title` | 18 / 800 | Judul app bar layar detail |
| `subtitle` | 15 / 800 | Judul seksi dan kartu |
| `bodyStrong` | 14 / 700 | Nama locker, label tombol |
| `body` | 14 / 400 | Teks isi |
| `bodySm` | 13 / 400 | Isi tabel, baris info |
| `caption` | 12 / 400 | Keterangan |
| `overline` | 11 / 700, spasi 0,8 | Label kecil huruf kapital |
| `micro` | 10 / 800 | Teks di dalam badge |

Angka timer dan durasi memakai tabular numbers agar tidak bergeser saat berdetik.

### Spasi, radius, ukuran

- **Spasi (skala 4):** 4, 8, 12, 16, 20, 24, 32, 40, 48.
- **Radius:** tag 6, field 12, button 14, card 16, hero 18, sheet 28, pill 999.
- **Ukuran penting:** area sentuh minimal 44; tombol utama mobile 52; app bar 56; bottom nav 80; topbar web 64; sidebar web 240; lebar konten maksimum 1136.
- **Breakpoint:** compact (di bawah 600) untuk HP, medium (600 ke atas) tablet, expanded (1024 ke atas) web admin.
- **Gerak:** fast 120 ms, base 200 ms, slow 320 ms, tahan-untuk-konfirmasi 2000 ms.
- **Bayangan:** hanya untuk bottom sheet dan popover; kartu memakai garis, bukan bayangan.

## 3. Komponen

| Komponen | Spesifikasi |
|---|---|
| **Badge status** | Pill tinggi 22, latar `container`, teks `text`, `micro`, huruf kapital |
| **Chip filter** | Pill tinggi 32; aktif latar `ink` teks putih, nonaktif `fillMuted` |
| **Kartu locker** | Radius `card`, garis `border`; bila perlu tindakan: latar `tint` dan garis `border` warna status. Isi: nomor di lingkaran, nama, penyewa atau keterangan, durasi, baris koneksi ESP32 |
| **Baris koneksi ESP32** | Titik 8 px hijau/merah + `ESP32-0X · Online · 2 dtk lalu`. Satu baris per locker karena satu ESP32 per locker |
| **Kartu KPI** | Label `caption`, angka 26 (mobile) atau 30 (web), keterangan `micro`; kartu perhatian memakai `tint` |
| **Checklist langkah** | Baris tinggi 68, lingkaran 28; selesai = hijau + centang, otomatis = garis putus |
| **Tombol utama** | Tinggi 52 (mobile) atau 44 (web), radius `button`, latar `primary`; nonaktif abu-abu disertai teks alasan |
| **Tombol bahaya** | Outline `danger` di layar biasa; solid `danger` hanya di sheet konfirmasi dengan tahan 2 detik |
| **Bottom sheet** | Radius atas `sheet`, handle 40x4, scrim opacity 0,55 |
| **Bottom nav** | Tinggi 80, indikator aktif pill `primaryContainer`, label 11 |
| **Sidebar web** | Lebar 240, latar `inverse`, item aktif latar `primary`, tinggi item 44 |
| **Tabel** | Header `surfaceMuted` 44, baris 52 (56 bila ada drawer), pemisah `fillMuted`, status berupa badge |
| **Drawer detail** | Lebar 416, kartu di kanan tabel; baris terpilih diberi `tint` dan strip kiri 4 px |

## 4. Pola per role dan platform

| Role / platform | Navigasi | Layar | Catatan |
|---|---|---|---|
| Petugas (Android) | Bottom nav: Locker, Riwayat, Akun | Beranda, Penanganan (checklist), Konfirmasi, Detail locker, Buka Darurat, Perangkat Offline | Mobile, satu tangan, aksi besar |
| Admin mobile | Bottom nav: Ringkasan, Riwayat, Log, Menu | Ringkasan, Riwayat Sewa, Log Audit | Pantau cepat dan cek log dari HP |
| Admin web | Sidebar 6 menu | Ringkasan, Riwayat Sewa, Log Audit (+ Locker & Perangkat, Petugas, Pengaturan) | Tabel lebar, ekspor CSV, drawer detail |
| Pelanggan (web) | Tanpa navigasi | Scan QR, form, kode sekali tampil | Hanya perlu `tokens.css`; tema dan status sama |

Aturan lintas role:
- Komponen yang sama dipakai ulang; hanya layout yang berubah mengikuti breakpoint (`screenClassOf` di Flutter).
- Hak akses mengubah **isi**, bukan gaya: Petugas tidak melihat tombol Admin, tetapi warna dan komponen sama.
- Setiap aksi sensitif (buka darurat, resolve, lihat nomor penuh, ubah pengaturan) menulis satu baris Log Audit dengan pelaku, waktu, locker, alasan, dan hasil.

## 5. Cara memakai

**Flutter (petugas, admin mobile, admin web, atau Flutter Web):**
1. Salin `flutter/app_tokens.dart` dan `flutter/app_theme.dart` ke `lib/theme/`.
2. Pasang font Inter (paket `google_fonts` atau aset lokal).
3. `MaterialApp(theme: buildAppTheme(), ...)`.
4. Warna status lewat `AppStatus.of(state)`; jangan memakai `Color(0x...)` langsung.
5. Jalankan `flutter analyze` karena file ini belum dikompilasi di lingkungan pembuatnya.

**HTML/CSS (halaman pelanggan):**
```html
<link rel="stylesheet" href="tokens.css">
<span class="badge" style="background:var(--state-disewa-container);color:var(--state-disewa-text)">DISEWA</span>
```

**Figma:**
1. Pasang plugin Tokens Studio, lalu impor `tokens/tokens.figma.json` (format JSON). Plugin akan membuat variabel warna, spasi, radius, dan gaya teks.
2. Impor SVG di folder `screens/` sebagai referensi tata letak.
3. Beri nama variabel mengikuti token, misalnya `color/success/main`, agar sama dengan kode.

**Mengubah desain:** edit `tokens/tokens.json`, lalu jalankan `python3 build_design_system.py`. CSS, token Figma, token Dart, dan layar admin akan dibuat ulang dari sumber yang sama.

## 6. Aksesibilitas

- Area sentuh minimal 44 px di mobile.
- Kontras teks status dipilih dari `text` di atas `container`, bukan `main` di atas putih untuk teks kecil.
- Status tidak hanya dibedakan lewat warna: selalu ada label teks atau ikon.
- Timer memakai tabular numbers; perubahan status penting juga dikirim sebagai notifikasi push, bukan hanya perubahan warna.

## 7. Isi folder

```
design-system/
  DESIGN_SYSTEM.md
  build_design_system.py
  tokens/    tokens.json (sumber), tokens.css, tokens.figma.json
  flutter/   app_tokens.dart (generated), app_theme.dart
  screens/   petugas-01..06 (mobile), admin-mobile-01..03, admin-web-01..03
```
