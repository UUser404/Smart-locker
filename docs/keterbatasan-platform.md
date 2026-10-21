# Dokumen Batasan Sistem & Platform — Smart Locker IoT

Dokumen ini merinci batasan (constraints) yang dihadapi dalam pengembangan sistem Smart Locker IoT. Batasan ini terbagi menjadi batasan perangkat keras, jaringan, perangkat lunak (platform), dan mengapa batasan tersebut penting untuk dipahami oleh tim pengembang dan stakeholder.

## 1. Batasan Perangkat Keras (Hardware)

- **Skala Prototipe Terbatas:** Sistem dirancang maksimal untuk 2 unit locker (dari rencana awal 4) yang dikendalikan oleh 1 unit ESP32. Penambahan locker membutuhkan penambahan pin I/O dan pemisahan jalur daya.
- **Pin Input-Only pada ESP32 (GPIO 34-39):** Pin yang digunakan untuk sensor pintu (limit switch) adalah input-only dan **tidak memiliki resistor pull-up internal**. Batasan ini memaksa tim hardware untuk memasang resistor eksternal 10kΩ agar sensor tidak membaca nilai acak (floating/flapping).
- **Keterbatasan Modul TFT ST7789 7-Pin:** Layar TFT yang digunakan tidak memiliki pin Chip Select (CS). Akibatnya, dua layar tidak bisa diparalel pada satu bus SPI. Selain itu, modul ini hanya mau menyala jika dikonfigurasi dengan SPI mode 3 dan pin Reset (RES) dihubungkan ke GPIO.
- **Ketergantungan Daya Eksternal:** Solenoid 12V membutuhkan arus besar (hingga 0.6A per unit). Ini mengharuskan penggunaan adaptor 12V eksternal dan diode flyback (1N4007) untuk mencegah lonjakan tegangan balik yang bisa merusak ESP32/relay.

## 2. Batasan Jaringan & Komunikasi

- **Keterbatasan Jaringan Kampus (NAT & Captive Portal):** ESP32 berada di jaringan lokal kampus (di balik NAT) sehingga tidak memiliki IP Publik. Backend (di internet) tidak bisa memanggil ESP32 secara langsung. Selain itu, WiFi kampus menggunakan _Captive Portal_ yang memblokir perangkat IoT; solusinya, MAC address ESP32 harus di-whitelist oleh IT kampus.
- **Solusi Arsitektur: Polling (Outgoing Only):** Karena tidak punya IP publik, komunikasi harus diinisiasi oleh ESP32 (polling ke backend). Konsekuensinya, ada latensi maksimal 2 detik untuk membuka locker (sesuai interval polling).
- **Batasan FCM (Firebase Cloud Messaging):** Jika HP petugas dalam keadaan offline, notifikasi ditahan oleh server Google (maksimal sesuai TTL yang diset, 30 menit). Jika lewat dari TTL, notifikasi dibuang.

## 3. Batasan Perangkat Lunak & Platform (Cloud)

- **Render.com Free Tier (Cold Start):** Backend di-hosting pada paket gratis Render. Server akan otomatis "tidur" jika tidak ada aktivitas selama 15 menit. Request pertama setelah tidur akan memakan waktu 30–60 detik. Ini berisiko memicu _Watchdog Timer_ (WDT) pada ESP32 yang diset 30 detik, berpotensi membuat ESP32 restart saat menunggu balasan server.
- **Batas Kuota Firestore:** Database Firestore memiliki batas gratis 20.000 _writes_ per hari. Jika backend menulis data secara agresif (misalnya merotasi token QR setiap 5 detik), kuota akan jebol dan sistem berhenti (Quota Exceeded).
- **Batasan Android (Battery Optimization):** OS Android (terutama Xiaomi, Oppo, Vivo) sering mematikan _background service_ aplikasi untuk menghemat baterai. Ini membuat notifikasi FCM _data-message_ tidak bisa memicu _auto-refresh_ UI secara instan jika aplikasi ditutup total.
- **iOS Web Push Terbatas:** Web pelanggan yang diakses via Safari (iPhone) tidak bisa menerima _push notification_ kecuali pengguna melakukan "Add to Home Screen". (Karena pelanggan tidak butuh notif, batasan ini tidak berdampak).

## 4. Batasan Keamanan & Lingkup Proyek

- **Tanpa Akun Permanen Pelanggan:** Pelanggan hanya diidentifikasi lewat nama, no HP, dan kode unik 1x lihat (SHA-256). Jika kode hilang, sistem tidak menyediakan fitur pemulihan (di luar scope).
- **Autentikasi Petugas Sederhana:** Login petugas menggunakan JWT (expire 7 hari) tanpa fitur _refresh token_. Akun di-seed manual, tidak ada fitur registrasi mandiri atau _reset password_ dari aplikasi.
- **Ketiadaan Sistem Pembayaran:** Prototipe kampus saat ini tidak memungut biaya. Sesi murni berbasis durasi parkir tanpa transaksi finansial.
