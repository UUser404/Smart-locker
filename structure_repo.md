.
├── firmware/
│ ├── src/
│ │ ├── main.cpp # setup() + loop(), inisialisasi AP/DNS/web server
│ │ ├── captive_portal.cpp/.h # logic AP mode + DNS redirect
│ │ ├── web_server.cpp/.h # routing endpoint HTTP (/pour, /stop, /hold, /status)
│ │ ├── pump_control.cpp/.h # kontrol relay + state 1-pompa-aktif + timeout auto-stop
│ │ └── config.h # SSID, pin relay, konstanta timeout, dll
│ ├── data/ # file HTML/CSS/JS untuk captive portal (di-serve dari SPIFFS/LittleFS)
│ │ ├── index.html
│ │ ├── style.css
│ │ └── script.js
│ └── platformio.ini (atau .ino kalau pakai Arduino IDE)
│
├── app/ # Project Flutter
│ └── lib/
│ ├── models/
│ │ └── dispenser_status.dart # representasi data dari /status
│ ├── services/
│ │ └── esp32_service.dart # semua HTTP call ke ESP32
│ ├── screens/
│ │ └── dispenser_screen.dart # halaman utama: carousel + Start/Stop
│ ├── widgets/
│ │ ├── flavor_carousel.dart # widget swipe pilih rasa
│ │ └── pour_button.dart # tombol Start/Stop + hold-to-pour
│ └── main.dart
│ # folder lain (android/, ios/, pubspec.yaml, dll) otomatis dibuat oleh `flutter create`
│
├── hardware/
│ ├── wiring_diagram.png # atau .fzz (Fritzing) / .pdf
│ ├── Komponen.excel # daftar komponen + harga + link beli
│ ├── datasheets/ # datasheet relay, pompa, ESP32, dll (PDF)
│ └── photos/ # foto progres rakitan
│
└── docs/
├── API.md # kontrak endpoint (sudah ada)
├── Dokumentasi_Konsep.md # dokumentasi konsep lengkap (sudah ada)
└── progress/ # catatan progres mingguan tiap tim (opsional)
