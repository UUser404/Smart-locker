# Hardware Wiring Guide — Smart Locker

Panduan lengkap _wiring_ & _assembly_ 4-unit Smart Locker untuk tim _hardware_. Ikuti urutan dari _bench test_ sampai _full assembly_.

- **PIC:** Alfian (hardware & elektronika)
- **Konsumen:** ESP32 firmware (Galuh)
- **Target:** 4 locker, 1 ESP32 controller

---

## 1. Daftar Komponen

### Wajib

| Komponen                     | Jumlah | Spesifikasi                         | Keterangan                     |
| ---------------------------- | ------ | ----------------------------------- | ------------------------------ |
| ESP32 DevKit                 | 1      | 38-pin, ESP32-D0WDQ6                | Sudah ada                      |
| Relay module                 | 1      | 4-channel, aktif LOW, 5V            |                                |
| Solenoid door lock           | 4      | 12V, fail-secure                    | 1 per locker                   |
| Sensor magnet / limit switch | 4      | NC atau NO, 2 kabel                 | 1 per locker                   |
| Resistor                     | 4      | 10 kΩ, 1/4 W                        | **Wajib** pull-up untuk sensor |
| TFT IPS ST7789               | 4      | 1.3", 240×240, SPI                  | 1 per locker, Pak Siswo beli   |
| Adaptor 12V                  | 1      | ≥ 3 A (4 solenoid × 0.6 A + margin) | Suplai utama                   |
| Buck converter               | 1      | 12V → 5V, ≥ 2 A                     | Untuk ESP32 + relay            |
| Diode 1N4007                 | 4-8    | 1 A, 1000 V                         | Flyback protection solenoid    |
| Terminal block               | 2-3    | 2 atau 4 jalur                      | Pembagi daya                   |
| Kabel jumper                 | 40+    | Male-male, male-female              |                                |

### Opsional / Cadangan

- Breadboard (untuk bench test)
- Kabel dupont female-female
- Heat shrink tube
- Kabel AWG 20 untuk jalur solenoid (12V, arus lumayan)

---

## 2. Pin Mapping ESP32

Dari `firmware/smart-locker/src/config.h` — **jangan ubah tanpa kabari Galuh**.

| Fungsi                    | GPIO | Mode       | Keterangan              |
| ------------------------- | ---- | ---------- | ----------------------- |
| **Relay IN1** (locker 0)  | 25   | Output     | Aktif LOW               |
| **Relay IN2** (locker 1)  | 26   | Output     | Aktif LOW               |
| **Relay IN3** (locker 2)  | 27   | Output     | Aktif LOW               |
| **Relay IN4** (locker 3)  | 32   | Output     | Aktif LOW               |
| **Sensor 0**              | 34   | Input-only | Butuh pull-up eksternal |
| **Sensor 1**              | 35   | Input-only | Butuh pull-up eksternal |
| **Sensor 2**              | 36   | Input-only | Butuh pull-up eksternal |
| **Sensor 3**              | 39   | Input-only | Butuh pull-up eksternal |
| **TFT SCLK** (shared)     | 18   | Output SPI | Semua TFT paralel       |
| **TFT MOSI/SDA** (shared) | 23   | Output SPI | Semua TFT paralel       |
| **TFT BLK** (shared)      | 19   | Output     | Bisa juga langsung 3.3V |
| **TFT CS0**               | 4    | Output     | Chip Select locker 0    |
| **TFT CS1**               | 13   | Output     | Chip Select locker 1    |
| **TFT CS2**               | 14   | Output     | Chip Select locker 2    |
| **TFT CS3**               | 33   | Output     | Chip Select locker 3    |
| **TFT DC0**               | 16   | Output     | Data/Command locker 0   |
| **TFT DC1**               | 17   | Output     | Data/Command locker 1   |
| **TFT DC2**               | 21   | Output     | Data/Command locker 2   |
| **TFT DC3**               | 22   | Output     | Data/Command locker 3   |
| Status LED                | 2    | Output     | Built-in di board       |

⚠️ **GPIO 34, 35, 36, 39 adalah input-only.** Tidak bisa jadi output. Tidak punya pull-up internal. **Wajib pakai resistor 10kΩ ke 3.3V.**

---

## 3. Wiring Diagram

### 3a. Power Distribution

```text
┌──────────────┐
│ Adaptor 12V  │
│    (3A+)     │
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
       │                                 ┌──────────┴──────┐
       │                                 ▼                 ▼
       │                             ESP32 VIN         Relay VCC
       │
       └──── GND ── Common Ground (semua GND gabung)
```

**Catatan penting:**

- **Semua GND harus common** (ESP32, relay, buck, adaptor 12V)
- Adaptor 12V GND = common ground
- Buck converter GND = common ground

### 3b. Relay → Solenoid (per locker)

```text
ESP32         Relay Module                 Solenoid 12V
─────         ────────────                 ────────────
GPIO 25 ────► IN1 ────────►│ Relay 1 │
                           │         │
+5V ────────► VCC          │         │
GND ────────► GND          │         │
                           │         │
              COM ─────────┴─────────► +12V (dari adaptor)
              NO  ───────────────────► Solenoid +

GND ─────────────────────────────────► Solenoid −
```

**Flyback diode (wajib):**

- Pasang paralel dengan solenoid
- Cathode (garis) → ke Solenoid +
- Anode (polos) → ke Solenoid −
- Fungsi: redam lonjakan tegangan saat solenoid mati

**Kenapa relay aktif LOW?**

- GPIO LOW = relay ON (solenoid energized)
- GPIO HIGH = relay OFF (solenoid de-energized)
- Ini default modul relay murah. Kalau punya kamu aktif HIGH, kabari Galuh untuk update firmware.

### 3c. Sensor Magnet / Limit Switch (per locker)

```text
3.3V
 │
10kΩ  ← resistor pull-up (WAJIB)
 │
 ├────── GPIO 34 (sensor 0)
 │
Sensor Magnet
(atau limit switch)
 │
GND
```

**Cara kerja:**

- Pintu **tertutup** → magnet dekat → sensor konduktif → GPIO = **LOW**
- Pintu **terbuka** → magnet jauh → sensor tidak konduktif → GPIO = **HIGH** (karena pull-up)
- Firmware membaca: `door_open = (digitalRead(34) == HIGH)`.

**Kalau pakai limit switch**, logikanya sama:

- Ditekan (pintu tertutup) → konduktif → LOW
- Tidak ditekan (pintu terbuka) → terbuka → HIGH

### 3d. TFT ST7789 4 Display (SPI shared)

```text
ESP32           TFT Locker 0   TFT Locker 1   TFT Locker 2   TFT Locker 3
─────           ────────────   ────────────   ────────────   ────────────
GPIO 18 (SCLK) ───┬──────────► SCL            SCL            SCL            SCL
GPIO 23 (MOSI) ───┼──────────► SDA            SDA            SDA            SDA
GPIO 19 (BLK)  ───┼──────────► BLK            BLK            BLK            BLK
3.3V           ───┼──────────► VCC            VCC            VCC            VCC
GND            ───┼──────────► GND            GND            GND            GND
3.3V           ───┼──────────► RES            RES            RES            RES
GPIO 4         ───┼──────────► CS             -              -              -
GPIO 13        ───┼─────────── -              CS             -              -
GPIO 14        ───┼─────────── -              -              CS             -
GPIO 33        ───┼─────────── -              -              -              CS
GPIO 16        ───┼──────────► DC             -              -              -
GPIO 17        ───┼─────────── -              DC             -              -
GPIO 21        ───┼─────────── -              -              DC             -
GPIO 22        ───┴─────────── -              -              -              DC
```

1. **Konsep:** SCLK, MOSI, BLK, VCC, GND, RES **shared** (paralel ke semua TFT). CS dan DC **individual per TFT** untuk memilih mana yang aktif.
2. **Total pin TFT:** 6 shared + 8 individual = 14 pin (sudah ada di pin mapping).

---

## 4. Urutan Assembly

### Fase A: Bench Test (1 relay, 1 sensor, 1 TFT)

_Jangan langsung rakit 4 locker. Bench test 1 set dulu._

1. **Wiring power** — adaptor 12V + buck converter. Cek output buck = 5V pakai multimeter sebelum colok ke ESP32.
2. **Wiring 1 relay** → 1 solenoid + flyback diode. Test: kasih LOW ke IN1, solenoid harus bunyi "tuk" dan terbuka.
3. **Wiring 1 sensor** + resistor pull-up. Test: tempel magnet, cek tegangan GPIO 34 dengan multimeter (harus ~0V saat magnet dekat, ~3.3V saat jauh).
4. **Wiring 1 TFT**. Upload firmware test, harus muncul QR.

_Kalau 4 test di atas lulus, baru lanjut Fase B._

### Fase B: Multi-Locker Assembly

5. **Wiring 4 relay** (sama seperti test, tinggal tambah 3 lagi).
6. **Wiring 4 sensor** (masing-masing dengan pull-up 10kΩ).
7. **Wiring 4 TFT** (SPI paralel + CS/DC individual).
8. **Mounting fisik** ke lemari.

### Fase C: Integration Test

9. Upload firmware production (`ENABLE_TFT true`, `ENABLE_DOOR_SENSOR true`).
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

_Kalau selalu 0V atau selalu 3.3V_: cek resistor pull-up, cek kabel, cek orientasi sensor.

### Test TFT

1. Upload firmware dengan `ENABLE_TFT true`.
2. Serial Monitor harus print: `[TFT] Init locker 0 (CS=4, DC=16)`.
3. Kalau crash/WDT trigger: cek wiring SPI (SCLK, MOSI, CS, DC).
4. Layar harusnya render QR setelah 10-15 detik.

---

## 6. Safety Notes

### Elektrikal

- **Selalu cek polaritas** sebelum colok power. Adaptor 12V salah arah bisa rusak ESP32 + relay + buck.
- **Common ground wajib.** Kalau ESP32 GND tidak terhubung ke adaptor GND, relay tidak akan trigger meski GPIO LOW.
- **Buck converter dulu di-trim** ke 5V sebelum colok ke ESP32. Buck default kadang output 12V, itu bisa rusak ESP32.
- **Diode flyback wajib** untuk solenoid. Tanpa diode, back-EMF bisa merusak relay atau ESP32.

### Mekanik

- Solenoid fail-secure: saat listrik mati, pintu **tetap terkunci**. Bagus untuk keamanan, tapi hati-hati saat test (jangan terkunci di dalam).
- Pastikan kabel tidak terjepit pintu saat locker ditutup.
- Sensor magnet harus **align** saat pintu tertutup. Kalau tidak, pintu akan terus dianggap terbuka.

---

## 7. Troubleshooting

| Gejala                               | Kemungkinan                               | Solusi                    |
| ------------------------------------ | ----------------------------------------- | ------------------------- |
| Relay tidak klik saat GPIO LOW       | Wiring IN salah, VCC relay tidak nyambung | Cek VCC=5V, GND common    |
| Solenoid bunyi lemah                 | Arus adaptor kurang                       | Ganti adaptor ≥3A         |
| Relay klik tapi solenoid tidak gerak | Flyback diode terbalik                    | Cek orientasi diode       |
| Sensor selalu baca LOW               | Resistor pull-up tidak terpasang          | Pasang 10kΩ ke 3.3V       |
| Sensor selalu baca HIGH              | Kabel sensor putus                        | Cek kontinuitas           |
| TFT blank putih                      | Wiring SPI salah                          | Cek SCLK=18, MOSI=23      |
| TFT crash firmware                   | TFT tidak respons                         | Cek VCC=3.3V, RES=3.3V    |
| ESP32 reset terus                    | Brownout (arus kurang)                    | Cek buck output ≥2A       |
| WiFi tidak connect                   | ESP32 tidak dapat IP                      | Cek kabel antena di board |

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

- [ ] Beli resistor 10kΩ (4x) — **prioritas #1**
- [ ] Beli diode 1N4007 (4-8x) — **prioritas #1**
- [ ] Beli adaptor 12V ≥3A
- [ ] Beli buck converter 12V→5V ≥2A
- [ ] Beli terminal block
- [ ] Beli kabel jumper male-female (untuk breadboard test)
- [ ] Bench test 1 relay + 1 solenoid
- [ ] Bench test 1 sensor + pull-up
- [ ] Bench test 1 TFT
- [ ] Wiring lengkap 4 relay
- [ ] Wiring lengkap 4 sensor
- [ ] Wiring lengkap 4 TFT
- [ ] Mounting ke lemari
- [ ] Integration test per locker
- [ ] Dokumentasi foto progress

---

## 10. Kontak

Kalau ada pertanyaan wiring atau firmware behavior:

- **Firmware:** Galuh (pin mapping, logic sensor, TFT)
- **Backend:** Galuh (device token, endpoint, dsb)
- **Fisik/casing:** Alfian (lemari, mounting)
