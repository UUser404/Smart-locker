# Hardware Wiring Guide — Smart Locker

Panduan lengkap wiring & assembly **2-unit** Smart Locker untuk tim
hardware. Ikuti urutan dari bench test sampai full assembly.

- **PIC:** Alfian (hardware & elektronika)
- **Konsumen:** ESP32 firmware (Galuh)
- **Target:** **2 locker** (locker_01, locker_02), 1 ESP32 controller

> **Catatan revisi:** Prototype final menggunakan **2 locker**. Firmware
> tetap support hingga 4 locker di level arsitektur (array pin sudah
> disiapkan), tapi yang diaktifkan via `ACTIVE_LOCKERS 2`. Pin index
> 2-3 tidak dipakai — biarkan kosong.

> **Update 15 Okt 2026 (hasil bench test TFT):** modul TFT yang dipakai bench
> test adalah ST7789 **7 pin tanpa pin CS**. Layar baru merespons dengan
> **SPI mode 3** dan **RES dihubungkan ke GPIO 5** (bukan ke 3V3). Lihat
> bagian 3d dan Test TFT. Limit switch dan relay/solenoid **belum diuji**.

---

## 1. Daftar Komponen

### Wajib

| Komponen                     | Jumlah | Spesifikasi                         | Keterangan                                          |
| ---------------------------- | ------ | ----------------------------------- | --------------------------------------------------- |
| ESP32 DevKit                 | 1      | 38-pin, ESP32-D0WDQ6                | Sudah ada                                           |
| Relay module                 | 1      | 4-channel, aktif LOW, 5V            | 2 channel dipakai, 2 channel idle                   |
| Solenoid door lock           | 2      | 12V, fail-secure                    | 1 per locker                                        |
| Sensor magnet / limit switch | 2      | NC atau NO, 2 kabel                 | 1 per locker                                        |
| Resistor                     | 2      | 10 kΩ, 1/4 W                        | **Wajib** pull-up untuk sensor                      |
| TFT IPS ST7789               | 2      | 1.3", 240×240, SPI                  | 1 per locker. Modul bench test: 7 pin, **tanpa CS** |
| Adaptor 12V                  | 1      | ≥ 2 A (2 solenoid × 0.6 A + margin) | Suplai utama                                        |
| Buck converter               | 1      | 12V → 5V, ≥ 2 A                     | Untuk ESP32 + relay                                 |
| Diode 1N4007                 | 2-4    | 1 A, 1000 V                         | Flyback protection solenoid                         |
| Terminal block               | 2-3    | 2 atau 4 jalur                      | Pembagi daya                                        |
| Kabel jumper                 | 20+    | Male-male, male-female              |                                                     |

### Opsional / Cadangan

- Breadboard (untuk bench test)
- Kabel dupont female-female
- Heat shrink tube
- Kabel AWG 20 untuk jalur solenoid (12V, arus lumayan)

**Catatan:** Kalau nanti mau scale-up ke 4 locker, tambah 2 solenoid,
2 sensor, 2 resistor, 2 TFT, dan 2 diode. Komponen lain (ESP32, relay,
adaptor, buck) sudah support 4 locker tanpa ganti.

---

## 2. Pin Mapping ESP32

Dari `firmware/smart-locker/src/config.h` — **jangan ubah tanpa kabari Galuh**.

### Pin Aktif (dipakai)

| Fungsi                    | GPIO | Mode       | Keterangan                                                                |
| ------------------------- | ---- | ---------- | ------------------------------------------------------------------------- |
| **Relay IN1** (locker_01) | 25   | Output     | Aktif LOW                                                                 |
| **Relay IN2** (locker_02) | 26   | Output     | Aktif LOW                                                                 |
| **Sensor 0** (locker_01)  | 34   | Input-only | Butuh pull-up eksternal                                                   |
| **Sensor 1** (locker_02)  | 35   | Input-only | Butuh pull-up eksternal                                                   |
| **TFT SCLK** (shared)     | 18   | Output SPI | Semua TFT paralel                                                         |
| **TFT MOSI/SDA** (shared) | 23   | Output SPI | Semua TFT paralel                                                         |
| **TFT BLK** (shared)      | 19   | Output     | Bisa juga langsung 3.3V                                                   |
| **TFT RES** (shared)      | 5    | Output     | Pulsa reset dari firmware (`TFT_RST_PIN`). Modul tanpa CS: jangan ke 3.3V |
| **TFT CS0** (locker_01)   | 4    | Output     | Chip Select locker_01 (hanya modul yang punya pin CS)                     |
| **TFT CS1** (locker_02)   | 13   | Output     | Chip Select locker_02 (hanya modul yang punya pin CS)                     |
| **TFT DC0** (locker_01)   | 16   | Output     | Data/Command locker_01                                                    |
| **TFT DC1** (locker_02)   | 17   | Output     | Data/Command locker_02                                                    |
| Status LED                | 2    | Output     | Built-in di board                                                         |

### Pin Idle (tidak dipakai untuk prototype 2 locker)

| Fungsi    | GPIO | Keterangan                   |
| --------- | ---- | ---------------------------- |
| Relay IN3 | 27   | Biarkan kosong               |
| Relay IN4 | 32   | Biarkan kosong               |
| Sensor 2  | 36   | Biarkan kosong (floating OK) |
| Sensor 3  | 39   | Biarkan kosong (floating OK) |
| TFT CS2   | 14   | Biarkan kosong               |
| TFT CS3   | 33   | Biarkan kosong               |
| TFT DC2   | 21   | Biarkan kosong               |
| TFT DC3   | 22   | Biarkan kosong               |

⚠️ **GPIO 34, 35 adalah input-only.** Tidak bisa jadi output. Tidak punya
pull-up internal. **Wajib pakai resistor 10kΩ ke 3.3V.**

---

## 3. Wiring Diagram

### 3a. Power Distribution

```text
┌──────────────┐
│ Adaptor 12V  │
│    (2A+)     │
└──────┬───────┘
       │
       │ +12V ────┬─────────────────────────────────┐
       │          │                                 │
       │       ┌──┴──┐                           ┌──┴──┐
       │       │Relay│                           │Buck │
       │       │COMx4│                           │12V→5V│
       │       └─────┘                           └──┬──┘
       │                                            │
       │                                           +5V
       │                                            │
       │                                  ┌──────────┴──────┐
       │                                  ▼                 ▼
       │                              ESP32 VIN          Relay VCC
       │
       └──── GND ── Common Ground (semua GND gabung)
```

**Catatan penting:**

- **Semua GND harus common** (ESP32, relay, buck, adaptor 12V)
- Adaptor 12V GND = common ground
- Buck converter GND = common ground

### 3b. Relay → Solenoid (per locker)

```text
ESP32            Relay Module                Solenoid 12V
─────            ────────────                ────────────
GPIO 25 ────────► IN1 ────►│ Relay 1 │
                           │         │
+5V ────────────► VCC      │         │
GND ────────────► GND      │         │
                           │         │
              COM ─────────┴─────────► +12V (dari adaptor)
              NO  ───────────────────► Solenoid +

GND ─────────────────────────────────► Solenoid −
```

**Untuk locker_02:** sama persis, tapi pakai `IN2` dan `GPIO 26`.

**Flyback diode (wajib):**

- Pasang paralel dengan solenoid
- Cathode (garis) → ke Solenoid +
- Anode (polos) → ke Solenoid −
- Fungsi: redam lonjakan tegangan saat solenoid mati

**Kenapa relay aktif LOW?**

- GPIO LOW = relay ON (solenoid energized)
- GPIO HIGH = relay OFF (solenoid de-energized)
- Ini default modul relay murah. Kalau punya kamu aktif HIGH, kabari Galuh
  untuk update firmware.

### 3c. Sensor Magnet / Limit Switch (per locker)

```text
3.3V
 │
10kΩ  ← resistor pull-up (WAJIB)
 │
 ├────── GPIO 34 (sensor locker_01)
 │
Sensor Magnet
(atau limit switch)
 │
GND
```

**Untuk locker_02:** sama persis, tapi ke `GPIO 35`.

**Limit switch:** sambungkan ke terminal **C** dan **NO** (bukan NC), dan pastikan
pintu benar-benar menekan tuasnya saat tertutup. Kalau tersambung ke NC,
logika terbuka/tertutup terbalik. _Pengujian limit switch di hardware ditunda
(belum dilakukan)._

**Cara kerja:**

- Pintu **tertutup** → magnet dekat → sensor konduktif → GPIO = **LOW**
- Pintu **terbuka** → magnet jauh → sensor tidak konduktif → GPIO = **HIGH** (karena pull-up)
- Firmware membaca: `door_open = (digitalRead(34) == HIGH)`

**Kalau pakai limit switch**, logikanya sama:

- Ditekan (pintu tertutup) → konduktif → LOW
- Tidak ditekan (pintu terbuka) → terbuka → HIGH

### 3d. TFT ST7789

#### 3d-1. Modul 7 pin tanpa CS — 1 layar (terbukti di bench test)

| Pin TFT | ESP32              |
| ------- | ------------------ |
| GND     | GND                |
| VCC     | 3V3 (bukan 5V)     |
| SCL     | GPIO 18            |
| SDA     | GPIO 23            |
| DC      | GPIO 16            |
| RES     | **GPIO 5**         |
| BLK     | 3V3 (atau GPIO 19) |

Syarat agar layar merespons: **SPI mode 3** dan **RES dipulsakan dari GPIO**.
Percobaan dengan RES ke 3V3 (mode 0 dan 3) dan RES GPIO + mode 2 tidak
menghasilkan tampilan.

#### 3d-2. Modul dengan pin CS — 2 layar (SPI shared)

_Diagram di bawah belum diuji di hardware. Untuk RES, hasil bench test
menyarankan GPIO daripada 3.3V._

```text
ESP32            TFT Locker_01   TFT Locker_02
─────            ─────────────   ─────────────
GPIO 18 (SCLK) ───┬──────────► SCL               SCL
GPIO 23 (MOSI) ───┼──────────► SDA               SDA
GPIO 19 (BLK)  ───┼──────────► BLK               BLK
3.3V           ───┼──────────► VCC               VCC
GND            ───┼──────────► GND               GND
3.3V           ───┼──────────► RES               RES
GPIO 4         ───┼──────────► CS                -
GPIO 13        ───┼─────────── -                 CS
GPIO 16        ───┼──────────► DC                -
GPIO 17        ───┴─────────── -                 DC
```

**Konsep:** SCLK, MOSI, BLK, VCC, GND, RES **shared** (paralel ke semua
TFT). CS dan DC **individual per TFT** untuk memilih mana yang aktif.

> **Catatan 2 layar tanpa CS (analisis, belum diuji):** tanpa pin CS, layar
> tidak bisa dipilih lewat chip select, jadi dua layar yang berbagi SCL/SDA
> akan menerima data yang sama. Perlu diputuskan: pakai modul yang punya pin
> CS, atau bus SPI terpisah per layar.

---

## 4. Urutan Assembly

### Fase A: Bench Test (1 relay, 1 sensor, 1 TFT)

Jangan langsung rakit 2 locker. Bench test 1 set dulu.

1. **Wiring power** — adaptor 12V + buck converter. Cek output buck = 5V
   pakai multimeter sebelum colok ke ESP32.
2. **Wiring 1 relay** → 1 solenoid + flyback diode. Test: kasih LOW ke
   IN1, solenoid harus bunyi "tuk" dan terbuka.
3. **Wiring 1 sensor** + resistor pull-up. Test: tempel magnet, cek
   tegangan GPIO 34 dengan multimeter (harus ~0V saat magnet dekat,
   ~3.3V saat jauh).
4. **Wiring 1 TFT** (tabel 3d-1). Upload tes mentah (`pio run -e rawtft -t upload`):
   layar harus berganti merah → hijau → biru → putih. Lalu upload `-e bench`
   untuk menguji teks dan QR lewat library.

Kalau 4 test di atas lulus, baru lanjut Fase B.

### Fase B: 2-Locker Assembly

5. **Wiring 2 relay** (sama seperti test, tinggal tambah 1 lagi ke GPIO 26).
6. **Wiring 2 sensor** (masing-masing dengan pull-up 10kΩ ke GPIO 35).
7. **Wiring 2 TFT** (SPI paralel + CS/DC individual).
8. **Mounting fisik** ke lemari 2 pintu.

### Fase C: Integration Test

9. Upload firmware production (`ACTIVE_LOCKERS 2`, `ENABLE_TFT true`, `ENABLE_DOOR_SENSOR true`).
10. Test per locker: rent → buka → tutup → kode unik → akhiri.
11. Test race condition (2 locker sekaligus).
12. Test timeout (pintu dibiarkan terbuka >2 menit).

---

## 5. Test Procedure per Komponen

### Test Relay

**Sebelum colok solenoid:**

1. Multimeter di mode continuity.
2. Colok probe ke COM dan NO.
3. Tanpa sinyal: harus **terbuka** (tidak kontinu).
4. Kasih GND ke IN1: relay klik, COM-NO harus **kontinu**.

**Setelah colok solenoid:**

1. Kasih GND ke IN1: solenoid bunyi "tuk", terkunci.
2. Lepas GND: solenoid bunyi lagi, terbuka.
3. Cek diode tidak panas (kalau panas, orientasi salah).

### Test Sensor

1. Multimeter di mode tegangan DC.
2. Probe hitam ke GND, probe merah ke pin GPIO 34.
3. **Pintu terbuka** (magnet jauh): harus ~3.3V.
4. **Pintu tertutup** (magnet dekat): harus ~0V.

Kalau selalu 0V atau selalu 3.3V: cek resistor pull-up, cek kabel, cek
orientasi sensor.

### Test TFT

**Tahap 1 — tes mentah (tanpa library):**

1. Wiring sesuai tabel 3d-1.
2. `pio run -e rawtft -t upload`, buka Serial Monitor (115200).
3. Serial: `[RAW] init selesai (RES pin: 5)`, lalu nama warna.
4. Layar berganti merah → hijau → biru → putih tiap 1,5 detik.
   _Status 15 Okt 2026: ✅ berhasil (SPI mode 3, RES GPIO 5)._

**Tahap 2 — library (`pio run -e bench -t upload`):**

1. Serial: `[TFT] Init locker 0 (CS=4, DC=16, RST=5)`.
2. Layar menampilkan "TFT OK", lalu QR (hitam di latar putih) yang berganti
   tiap 5 detik. Scan dengan HP: hasilnya `locker_01.tokXXXX`.
   _Status 15 Okt 2026: tulisan "TFT OK" ✅ tampil; **QR belum tampil**
   (penyebab belum diketahui)._
3. Kalau crash/WDT trigger: cek wiring SPI (SCLK, MOSI, DC, RES).

---

## 6. Safety Notes

### Elektrikal

- **Selalu cek polaritas** sebelum colok power. Adaptor 12V salah arah
  bisa rusak ESP32 + relay + buck.
- **Common ground wajib.** Kalau ESP32 GND tidak terhubung ke adaptor
  GND, relay tidak akan trigger meski GPIO LOW.
- **Buck converter dulu di-trim** ke 5V sebelum colok ke ESP32. Buck
  default kadang output 12V, itu bisa rusak ESP32.
- **Diode flyback wajib** untuk solenoid. Tanpa diode, back-EMF bisa
  merusak relay atau ESP32.

### Mekanik

- Solenoid fail-secure: saat listrik mati, pintu **tetap terkunci**.
  Bagus untuk keamanan, tapi hati-hati saat test (jangan terkunci
  di dalam).
- Pastikan kabel tidak terjepit pintu saat locker ditutup.
- Sensor magnet harus **align** saat pintu tertutup. Kalau tidak, pintu
  akan terus dianggap terbuka.

---

## 7. Troubleshooting

| Gejala                               | Kemungkinan                               | Solusi                                              |
| ------------------------------------ | ----------------------------------------- | --------------------------------------------------- |
| Relay tidak klik saat GPIO LOW       | Wiring IN salah, VCC relay tidak nyambung | Cek VCC=5V, GND common                              |
| Solenoid bunyi lemah                 | Arus adaptor kurang                       | Ganti adaptor ≥2A                                   |
| Relay klik tapi solenoid tidak gerak | Flyback diode terbalik                    | Cek orientasi diode                                 |
| Sensor selalu baca LOW               | Resistor pull-up tidak terpasang          | Pasang 10kΩ ke 3.3V                                 |
| Sensor selalu baca HIGH              | Kabel sensor putus                        | Cek kontinuitas                                     |
| TFT blank putih                      | Wiring SPI salah                          | Cek SCLK=18, MOSI=23                                |
| TFT crash firmware                   | TFT tidak respons                         | Cek VCC=3.3V, RES (GPIO 5 untuk modul tanpa CS)     |
| TFT backlight nyala, layar gelap     | Modul tanpa CS: SPI mode / reset salah    | SPI mode 3 + RES ke GPIO 5                          |
| Build gagal `pins_arduino.h` hilang  | Paket framework Arduino-ESP32 rusak       | Hapus & unduh ulang paket di `.platformio\packages` |
| ESP32 reset terus                    | Brownout (arus kurang)                    | Cek buck output ≥2A                                 |
| WiFi tidak connect                   | ESP32 tidak dapat IP                      | Cek kabel antena di board                           |

---

## 8. Referensi

- **Firmware config:** `firmware/smart-locker/src/config.h`
- **Backend API:** `docs/API.md`
- **Firmware docs:** `firmware/smart_locker_firmware_documentation.md`
- **Datasheet:**
  - ESP32: Espressif ESP32 Series Datasheet
  - ST7789: Sitronix ST7789 datasheet
  - Solenoid 12V: sesuai merek yang dibeli
  - Relay: sesuai merek modul

---

## 9. Checklist untuk Alfian

- [ ] Beli resistor 10kΩ (2x) — **prioritas #1**
- [ ] Beli diode 1N4007 (2-4x) — **prioritas #1**
- [ ] Beli adaptor 12V ≥2A
- [ ] Beli buck converter 12V→5V ≥2A
- [ ] Beli terminal block
- [ ] Beli kabel jumper male-female (untuk breadboard test)
- [ ] Bench test 1 relay + 1 solenoid
- [ ] Bench test 1 sensor + pull-up
- [ ] Bench test 1 TFT
- [ ] Wiring lengkap 2 relay
- [ ] Wiring lengkap 2 sensor
- [ ] Wiring lengkap 2 TFT
- [ ] Mounting ke lemari 2 pintu
- [ ] Integration test per locker
- [ ] Dokumentasi foto progress

---

## 10. Kontak

Kalau ada pertanyaan wiring atau firmware behavior:

- **Firmware:** Galuh (pin mapping, logic sensor, TFT)
- **Backend:** Galuh (device token, endpoint, dsb)
- **Fisik/casing:** Alfian (lemari, mounting)

---

## Rekap Perubahan dari Versi 4 Locker

| Section            | Yang diubah                                                             |
| ------------------ | ----------------------------------------------------------------------- |
| Header             | Target 4 → 2 locker + catatan revisi                                    |
| 1. Komponen        | Jumlah: 4 → 2 (solenoid, sensor, resistor, TFT, diode). Adaptor 3A → 2A |
| 2. Pin mapping     | Split jadi "Pin Aktif" (2 locker) dan "Pin Idle" (biarkan kosong)       |
| 3. Wiring diagram  | Semua diagram diupdate untuk 2 TFT + 2 relay + 2 sensor                 |
| 4. Assembly        | Fase B: 4 → 2 locker                                                    |
| 5. Test            | Sama, tidak berubah                                                     |
| 7. Troubleshooting | Adaptor ≥3A → ≥2A                                                       |
| 9. Checklist       | Semua item 4x → 2x, prioritas adaptor                                   |

---

## Rekap Perubahan — Update 15 Okt 2026

| Section            | Yang diubah                                                                                |
| ------------------ | ------------------------------------------------------------------------------------------ |
| Header             | Catatan hasil bench test TFT (7 pin tanpa CS, SPI mode 3, RES GPIO 5)                      |
| 1. Komponen        | Baris TFT: modul bench test tanpa CS                                                       |
| 2. Pin mapping     | Tambah TFT RES (GPIO 5), catatan CS hanya untuk modul ber-CS                               |
| 3c. Sensor         | Catatan limit switch (terminal C + NO), pengujian ditunda                                  |
| 3d. TFT            | Dipecah: 3d-1 modul tanpa CS (terbukti), 3d-2 modul ber-CS (belum diuji) + catatan 2 layar |
| 4. Assembly        | Fase A langkah 4: tes mentah lalu bench                                                    |
| 5. Test TFT        | Tahap 1 (mentah) dan tahap 2 (library) + status                                            |
| 7. Troubleshooting | Tambah: backlight nyala layar gelap; `pins_arduino.h` hilang; RES                          |
| Perbaikan format   | Pagar kode ```` rusak di bagian 3a dan akhir dokumen dihapus                               |
