# Smart Dispenser IoT (3 Rasa)

Alat penuang minuman otomatis dengan 3 saluran rasa (susu, kopi, teh, atau varian lain), dikendalikan tamu langsung dari HP mereka lewat dua jalur kontrol:

1. **Captive portal (web based)** — connect ke WiFi dispenser, interface muncul otomatis.
2. **App Flutter (Android)** — kontrol alternatif, dikembangkan untuk tugas mata kuliah _Pemrograman Berbasis Platform_.

Dibangun sebagai project pembelajaran IoT/elektronika sekaligus pemrograman platform, dengan target penggunaan nyata di acara (pernikahan, gathering, bazar).

---

## Struktur Repo

```
.
├── firmware/     # Kode ESP32 (captive portal, web server, kontrol relay/pompa)
├── app/          # Project Flutter (UI kontrol + koneksi HTTP ke ESP32)
├── hardware/     # Wiring diagram, BOM (bill of materials), datasheet komponen, foto rakitan
└── docs/         # Dokumentasi konsep, kontrak API, catatan progres
    ├── API.md
    └── Dokumentasi_Konsep.md
```

---

## Tim & Pembagian Tugas

| Nama         | Scope                  | Tanggung Jawab Utama                                                          |
| ------------ | ---------------------- | ----------------------------------------------------------------------------- |
| _(isi nama)_ | Hardware & Elektronika | Wiring ESP32 + relay + pompa, power supply, casing/mekanik                    |
| _(isi nama)_ | Firmware ESP32         | Captive portal, web UI, endpoint HTTP, logika 1-pompa-aktif & multi-user lock |
| _(isi nama)_ | App Flutter            | UI carousel rasa, tombol Start/Stop, hold-to-pour, koneksi HTTP ke ESP32      |

Kontrak endpoint HTTP antara firmware dan app didokumentasikan di [`docs/API.md`](docs/API.md) — **selalu update dokumen ini kalau ada perubahan endpoint**, supaya tim lain tidak break.

---

## Arsitektur Singkat

- **Mikrokontroler:** ESP32 sebagai Access Point + DNS server + Web server sekaligus
- **Kontrol pompa:** 3× relay module (aktif LOW), masing-masing switch 1 pompa dinamo 12V
- **Single source of truth:** status pompa & flavor aktif dikelola di ESP32, diakses baik oleh web captive portal maupun app Flutter lewat endpoint HTTP yang sama

Detail lengkap ada di [`docs/Dokumentasi_Konsep.md`](docs/Dokumentasi_Konsep.md).

---

## Cara Kerja Branch

- `main` — kode stabil & sudah teruji
- `feature/firmware-*` — pengembangan firmware ESP32
- `feature/app-*` — pengembangan app Flutter
- `feature/hardware-*` — dokumentasi wiring, kalibrasi, casing

Merge ke `main` lewat Pull Request, bukan push langsung.

## Tracking Progress

Gunakan tab **Issues** dan **Projects** (kanban: To Do / In Progress / Done) di repo ini untuk tracking task per orang.
