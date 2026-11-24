# Redesain UI Flutter

Dokumen ini mencatat implementasi app Petugas/Admin terhadap mockup SVG pada
[`ChangeRequest_flutter/`](./ChangeRequest_flutter/) dan membedakan pekerjaan UI
dari kebutuhan data atau operasi backend.

## Status implementasi

| Mockup | Implementasi Flutter | Batasan saat ini |
|---|---|---|
| Beranda Petugas | Ringkasan status, daftar locker, panel tindakan, durasi pintu terbuka, navigasi bawah | Nama unit, koneksi ESP32, dan aktivitas terbaru tidak tersedia dari API |
| Penanganan locker | Checklist pemeriksaan fisik dan tombol penyelesaian yang terkunci sampai checklist lengkap | Status sensor pintu tidak tersedia dari API |
| Konfirmasi kosongkan | Konfirmasi sebelum memanggil endpoint resolve | Backend hanya mengubah status locker; pencatatan audit belum tersedia |
| Detail locker | Status, durasi, dan tindakan berdasarkan status locker | Detail penyewa dan konektivitas perangkat tidak tersedia di endpoint Petugas |
| Buka darurat | Pesan aksi tersedia/tidak tersedia ditampilkan tanpa menjalankan operasi | Endpoint buka darurat dan pencatatan alasan/audit belum tersedia; aksi tidak boleh diaktifkan dari UI saja |
| Perangkat offline | UI belum bisa mengidentifikasi keadaan offline secara dinamis | Model/API locker belum menyediakan status offline atau waktu `last_seen`; belum ada state perangkat offline yang nyata |
| Admin mobile | Ringkasan, riwayat sewa, log audit, dan menu melalui navigasi bawah | Data log audit dan jumlah buka darurat belum tersedia; nilai tersebut ditandai belum tersedia |
| Admin web | Sidebar, header, banner perhatian, KPI, kartu locker dua kolom, panel kejadian, panel pemakaian, riwayat berbentuk tabel, dan halaman log audit | Panel kejadian/pemakaian dan data audit memakai state belum tersedia karena endpoint belum ada; Manajemen Petugas/Pengaturan belum didukung API |

Warna dan struktur komponen dapat dibuat mengikuti mockup di Flutter. Yang belum
bisa direplikasi sebagai data nyata adalah nilai yang belum dikirim server:
menampilkan "Online", riwayat kejadian, log audit, atau hasil buka darurat
tanpa sumber data akan membuat UI menyesatkan. Untuk bagian tersebut, aplikasi
menampilkan status belum tersedia dan bukan data contoh.

## Sumber visual

- Token desain: [`ChangeRequest_flutter/DESIGN_SYSTEM.md`](./ChangeRequest_flutter/DESIGN_SYSTEM.md)
- Mockup Petugas: `01-beranda-petugas-v2.svg` sampai `06-perangkat-offline.svg`
- Mockup Admin mobile: `admin-mobile-01-ringkasan.svg` sampai `admin-mobile-03-log-audit.svg`
- Mockup Admin web: `admin-web-01-ringkasan.svg` sampai `admin-web-03-log-audit.svg`
- Implementasi token Flutter: [`app_tokens.dart`](../../mprojectapp/lib/theme/app_tokens.dart) dan [`app_theme.dart`](../../mprojectapp/lib/theme/app_theme.dart)

## Batas integrasi yang diperlukan

Untuk melengkapi data dan aksi di mockup, API/backend perlu menyediakan:

1. Status koneksi perangkat per locker, identitas ESP32, dan waktu sinkron/`last_seen`.
2. Log kejadian untuk aktivitas terakhir, termasuk waktu, locker, dan status.
3. Riwayat audit dengan pelaku, alasan, hasil, dan filter jenis tindakan.
4. Operasi buka darurat yang terotorisasi, meminta alasan, dan mencatat hasil ke audit.
5. Data sensor pintu dan detail penyewa yang boleh dilihat sesuai role.

Mockup merupakan target visual, bukan bukti bahwa endpoint di atas sudah
tersedia. Perubahan API/firmware, termasuk proposal QR scan, berada di luar
cakupan redesain UI Flutter ini.

## Verifikasi lokal

Dari folder `mprojectapp`:

```powershell
flutter test --no-pub
flutter build web --no-pub
flutter build apk --debug --no-pub
```

Jika hanya layout Flutter yang berubah, APK harus dibangun ulang dan dipasang
kembali agar perangkat tidak masih menjalankan artefak lama. Build Android
memerlukan Android SDK yang dikonfigurasi pada mesin pengembang.
