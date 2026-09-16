.
├── firmware/
│ ├── src/
│ │ ├── main.cpp # setup() + loop(), inisialisasi WiFi client & relay/sensor
│ │ ├── wifi_client.cpp/.h # koneksi ESP32 ke WiFi (STA mode) - beda dari dispenser yang AP mode
│ │ ├── lock_control.cpp/.h # kontrol relay + solenoid per locker (0-3), skema fail-secure
│ │ ├── door_sensor.cpp/.h # baca sensor magnet (reed switch) tiap locker, deteksi buka/tutup
│ │ ├── http_endpoint.cpp/.h # endpoint HTTP (/unlock) yang dipanggil backend, bukan user langsung
│ │ └── config.h # SSID/password WiFi, pin relay & sensor magnet per locker, konstanta timeout
│ └── platformio.ini (atau .ino kalau pakai Arduino IDE)
│
├── backend/ # BARU - tidak ada di project dispenser
│ ├── src/
│ │ ├── index.js # entry point server
│ │ ├── routes/
│ │ │ ├── auth.js # /api/register, /api/login
│ │ │ ├── rentals.js # /api/rentals, /activate, /end, /status
│ │ │ └── lockers.js # /api/lockers (daftar status tiap locker)
│ │ ├── models/
│ │ │ ├── user.js
│ │ │ ├── rental.js # termasuk started_at, ended_at, total_duration_seconds
│ │ │ └── locker.js
│ │ ├── services/
│ │ │ └── firmware_client.js # kirim perintah unlock ke IP ESP32 locker yang sesuai
│ │ └── config/
│ │ └── db.js # koneksi database
│ ├── package.json
│ └── .env.example # kredensial database, secret, dll
│
├── app/ # Project Flutter (Android)
│ └── lib/
│ ├── models/
│ │ ├── user.dart
│ │ └── rental_status.dart # started_at, elapsed_seconds
│ ├── services/
│ │ ├── api_service.dart # semua HTTP call ke backend
│ │ └── barcode_scanner_service.dart # wrapper package scanner (mis. mobile_scanner)
│ ├── screens/
│ │ ├── login_screen.dart
│ │ ├── register_screen.dart
│ │ ├── scan_screen.dart # scanner kamera untuk baca barcode locker
│ │ └── rental_status_screen.dart # durasi berjalan (naik terus) + tombol akhiri sewa
│ ├── widgets/
│ │ └── duration_counter.dart # tampilan durasi berjalan, bukan countdown
│ └── main.dart
│ # folder lain (android/, ios/, pubspec.yaml, dll) otomatis dibuat oleh `flutter create`
│
├── hardware/
│ ├── wiring_diagram.png # atau .fzz (Fritzing) / .pdf
│ ├── RAB.xlsx # rencana anggaran biaya (bukan cuma daftar komponen)
│ ├── datasheets/ # datasheet solenoid lock, relay, reed switch, ESP32
│ └── photos/ # foto progres rakitan 4 unit locker
│
└── docs/
├── API.md # kontrak endpoint (sudah ada)
├── DEVELOPMENT_GUIDE.md # dokumentasi konsep lengkap (sudah ada)
├── elisitasi/ # BARU - hasil teknik elisitasi
│ ├── Wawancara_Pengguna_Akhir.docx
│ ├── Wawancara_Pengelola_Aset_Kampus.docx
│ ├── Wawancara_IT_Jaringan_Kampus.docx
│ └── Wawancara_Keamanan_Kebersihan.docx
└── progress/ # catatan progres mingguan tiap tim (opsional)
