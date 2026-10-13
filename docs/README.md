# Dokumentasi Smart Locker IoT

Index lengkap dokumentasi proyek Smart Locker IoT.

## Untuk Siapa?

- **Tim pengembang** (Galuh, Alfian, Reza) — referensi harian
- **Dosen penguji** — konteks proyek & keputusan teknis
- **Stakeholder** — gambaran umum sistem

---

## Daftar Dokumen

### 📋 Konsep & Requirement

| Dokumen                                                                    | Deskripsi                                                          |
| -------------------------------------------------------------------------- | ------------------------------------------------------------------ |
| [SKPL Smart Locker IoT-final.docx](SKPL%20Smart%20Locker%20IoT-final.docx) | Spesifikasi Kebutuhan Perangkat Lunak (20 functional requirements) |
| [DEVELOPMENT_GUIDE.md](DEVELOPMENT_GUIDE.md)                               | Konsep lengkap: 5W1H, arsitektur, RAB, alur pengerjaan             |
| [API.md](API.md)                                                           | Kontrak resmi endpoint backend ↔ firmware ↔ web ↔ app              |

### 🏗️ Backend

| Dokumen                     | Lokasi                                                                                     | Deskripsi                 |
| --------------------------- | ------------------------------------------------------------------------------------------ | ------------------------- |
| Progress backend & firmware | [../firmware/DOKUMENTASI_PROGRESS_BACKEND.md](../firmware/DOKUMENTASI_PROGRESS_BACKEND.md) | Progress 5 batch + 5 fase |
| Backend source code         | [../backend-express/](../backend-express/)                                                 | Express + Firestore       |

### 🔧 Firmware

| Dokumen               | Lokasi                                                                                                   | Deskripsi                                |
| --------------------- | -------------------------------------------------------------------------------------------------------- | ---------------------------------------- |
| Dokumentasi firmware  | [../firmware/smart_locker_firmware_documentation.md](../firmware/smart_locker_firmware_documentation.md) | Firmware ESP32 v3.1                      |
| Hardware wiring guide | [../firmware/HARDWARE_WIRING_GUIDE.md](../firmware/HARDWARE_WIRING_GUIDE.md)                             | Wiring guide untuk tim hardware (Alfian) |
| Firmware source code  | [../firmware/smart-locker/](../firmware/smart-locker/)                                                   | Project PlatformIO                       |

### 📱 Web & App (Reza)

| Dokumen              | Lokasi                                                   | Deskripsi                |
| -------------------- | -------------------------------------------------------- | ------------------------ |
| Progress app petugas | [../DOKUMENTASI_PROGRESS.md](../DOKUMENTASI_PROGRESS.md) | Progress Flutter Android |
| Setup web pelanggan  | [../README_WEB.md](../README_WEB.md)                     | Flutter Web              |
| Dokumentasi Flutter  | [dokumentasi flutter/](dokumentasi%20flutter/)           | Folder referensi Flutter |

### 🎯 Demo & Presentasi

| Dokumen                                                                                        | Deskripsi                                                      |
| ---------------------------------------------------------------------------------------------- | -------------------------------------------------------------- |
| [CHEAT_SHEET_DEMO.md](CHEAT_SHEET_DEMO.md)                                                     | Panduan demo hari H (persiapan + alur + troubleshooting + FAQ) |
| [Diagram Alur Smart Locker.docx](Diagram%20Alur%20Smart%20Locker.docx)                         | Diagram arsitektur & alur untuk slide                          |
| [Alur Data dan Komponen Smart Locker.docx](Alur%20Data%20dan%20Komponen%20Smart%20Locker.docx) | Alur data & komponen sistem                                    |

### 📊 Elisitasi & Stakeholder

| Dokumen                  | Deskripsi                     |
| ------------------------ | ----------------------------- |
| [elisitasi/](elisitasi/) | Hasil wawancara 4 stakeholder |

---

## Struktur Proyek

```text
Smart-Locker/
├── backend-express/ # Backend Express + Firestore (Galuh)
├── firmware/ # Firmware ESP32 (Galuh)
│ ├── smart-locker/ # Project PlatformIO
│ └── *.md # Dokumentasi firmware
├── mprojectapp/ # App Flutter petugas (Reza)
├── web/ # Web pelanggan Flutter (Reza)
├── hardware/ # Wiring, RAB, foto (Alfian)
└── docs/ # Dokumentasi (file ini)
```

---

## Kontak Tim

| Nama       | Scope                  | Folder                          |
| ---------- | ---------------------- | ------------------------------- |
| **Galuh**  | Backend & Firmware     | `backend-express/`, `firmware/` |
| **Alfian** | Hardware & Elektronika | `hardware/`                     |
| **Reza**   | Web & App Petugas      | `web/`, `mprojectapp/`          |

---

## Link Eksternal

| Resource               | URL                                                                    |
| ---------------------- | ---------------------------------------------------------------------- |
| **GitHub Repo**        | https://github.com/UUser404/Smart-locker                               |
| **Backend Production** | https://smart-locker-backend-a2ck.onrender.com                         |
| **Firebase Console**   | https://console.firebase.google.com/project/smart-locker-project-45bac |
| **Render Dashboard**   | https://dashboard.render.com                                           |

---

## Cara Update Dokumen

1. Update file yang relevan
2. Commit dengan pesan jelas: `docs: <apa yang diubah>`
3. Push ke branch `feature/firmware`
4. Update index ini kalau menambah file baru

---

## Referensi Cepat

**Skenario umum:**

| Kalau kamu mau...        | Buka                                                                                                                     |
| ------------------------ | ------------------------------------------------------------------------------------------------------------------------ |
| Lihat arsitektur sistem  | [DEVELOPMENT_GUIDE.md](DEVELOPMENT_GUIDE.md) atau [Diagram Alur Smart Locker.docx](Diagram%20Alur%20Smart%20Locker.docx) |
| Cek endpoint API         | [API.md](API.md)                                                                                                         |
| Demo hari H              | [CHEAT_SHEET_DEMO.md](CHEAT_SHEET_DEMO.md)                                                                               |
| Wiring hardware          | [../firmware/HARDWARE_WIRING_GUIDE.md](../firmware/HARDWARE_WIRING_GUIDE.md)                                             |
| Cek progress keseluruhan | [../firmware/DOKUMENTASI_PROGRESS_BACKEND.md](../firmware/DOKUMENTASI_PROGRESS_BACKEND.md)                               |
| Lihat SKPL               | [SKPL Smart Locker IoT-final.docx](SKPL%20Smart%20Locker%20IoT-final.docx)                                               |
