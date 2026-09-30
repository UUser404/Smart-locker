\# Smart Locker — Web Pelanggan (Flutter Web)



Halaman web pelanggan, dibangun pakai Flutter supaya gaya kode \& komponen

konsisten dengan app petugas (`app/` — Flutter Android).



\## Sebelum mulai



Ganti `kApiBase` di `lib/api\_service.dart` ke domain backend asli.



\## Menjalankan saat development



```bash

flutter pub get

flutter run -d chrome

```



\## Build untuk deploy



```bash

flutter build web

```



Hasilnya ada di `build/web/` — upload folder ini ke hosting statis mana pun

(Netlify, Vercel, Nginx, dst).



\## Catatan penting



\- \*\*Kamera perlu HTTPS.\*\* Browser hanya mengizinkan akses kamera (`getUserMedia`,

&#x20; dipakai `mobile\_scanner`) di halaman \*\*HTTPS\*\* atau `localhost`. Saat development

&#x20; `flutter run -d chrome` otomatis pakai `localhost` jadi aman; saat deploy,

&#x20; pastikan hosting-nya HTTPS (bukan HTTP polos).

\- \*\*Bundle lebih berat\*\* dibanding versi HTML/JS murni sebelumnya — wajar untuk

&#x20; Flutter Web, karena ada runtime Dart→JS yang ikut ter-download.

\- Sesi lokal (`rental\_id` untuk menampilkan durasi berjalan kalau locker yang sama

&#x20; di-scan ulang) disimpan lewat `shared\_preferences`, yang di Flutter Web memakai

&#x20; `localStorage` browser — bukan pengganti kode unik, cuma kenyamanan tampilan.

