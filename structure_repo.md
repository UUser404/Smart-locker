.
├── firmware/
│ ├── src/
│ │ ├── main.cpp # setup() + loop(), inisialisasi WiFi client, polling loop
│ │ ├── wifi_client.cpp/.h # koneksi ESP32 ke WiFi kampus (STA mode)
│ │ ├── backend_poller.cpp/.h # polling GET /api/firmware/{id}/poll tiap 2 detik, eksekusi command
│ │ ├── lock_control.cpp/.h # kontrol relay + solenoid per locker (0-3), skema fail-secure
│ │ ├── door_sensor.cpp/.h # baca sensor magnet tiap locker, deteksi opened/closed, debounce
│ │ ├── event_reporter.cpp/.h # kirim POST /api/firmware/{id}/report saat status pintu berubah
│ │ └── config.h # SSID/password WiFi, base URL backend, pin relay & sensor per locker
│ └── platformio.ini (atau .ino kalau pakai Arduino IDE)
│
├── backend/
│ ├── src/
│ │ ├── index.js # entry point server
│ │ ├── routes/
│ │ │ ├── lockers.js # GET /status, POST /rent, POST /access
│ │ │ ├── rentals.js # GET /rentals/{id}/status
│ │ │ ├── firmware.js # GET /firmware/{id}/poll, POST /firmware/{id}/report
│ │ │ └── admin.js # GET /admin/lockers, POST /admin/lockers/{id}/resolve
│ │ ├── models/
│ │ │ ├── rental.js # started_at, ended_at, total_duration_seconds, action (continue/end)
│ │ │ └── locker.js # status: empty/occupied/needs_attention, unlocked_since
│ │ ├── services/
│ │ │ ├── unique_code.js # generate kode unik + hashing (mirip password hashing)
│ │ │ ├── command_queue.js # antrian perintah unlock per locker, diambil saat firmware polling
│ │ │ ├── timeout_monitor.js # job berkala cek locker "unlocked" > 2 menit tanpa event closed
│ │ │ └── rate_limiter.js # batasi percobaan kode salah per locker
│ │ └── config/
│ │ └── db.js # koneksi database
│ ├── package.json
│ └── .env.example # kredensial database, secret hashing, dll
│
├── web/
│ ├── public/
│ │ ├── scan.html # halaman hasil scan barcode - render beda tergantung status locker
│ │ ├── admin.html # dashboard status locker untuk petugas
│ │ ├── style.css
│ │ └── script.js # fetch status locker, submit form sewa, submit kode unik, polling durasi
│ └── README.md # cara build/deploy halaman web (kalau pakai framework, sesuaikan)
│
├── hardware/
│ ├── wiring_diagram.png # atau .fzz (Fritzing) / .pdf
│ ├── RAB.xlsx # rencana anggaran biaya
│ ├── datasheets/ # datasheet solenoid lock, relay, reed switch, ESP32
│ └── photos/ # foto progres rakitan 4 unit locker
│
└── docs/
├── API.md # kontrak endpoint (sudah ada)
├── DEVELOPMENT_GUIDE.md # dokumentasi konsep lengkap (sudah ada)
├── elisitasi/ # hasil teknik elisitasi
│ ├── Wawancara_Pengguna_Akhir.docx
│ ├── Wawancara_Pengelola_Aset_Kampus.docx
│ ├── Wawancara_IT_Jaringan_Kampus.docx
│ └── Wawancara_Keamanan_Kebersihan.docx
└── progress/ # catatan progres mingguan tiap tim (opsional)
