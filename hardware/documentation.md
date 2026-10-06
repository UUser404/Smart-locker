Berikut adalah rancangan perancangan *wiring* dan rangkaian elektronika untuk sistem Smart Locker IoT yang dipegang oleh Alfian, disesuaikan dengan daftar komponen pada RAB (`hardware/RAB.xlsx`) dan arsitektur kontrol ESP32:

---

# RANCANGAN WIRING & RANGKAIAN ELEKTRONIKA SMART LOCKER IoT

## 1. Daftar Kebutuhan Hardware Elektronika (Berdasarkan RAB)

* **Microcontroller:** ESP32 NodeMCU Module (1 unit)


* **Kontrol Solenoid:** Modul Relay 4 Channel (Aktif LOW, 1 unit)


* **Aktuator Pengunci:** Solenoid Door Lock 12V tipe *fail-secure* (4 unit)


* **Sensor Pintu:** Magnetic Door Sensor / Reed Switch (4 unit)


* **Tampilan QR:** TFT IPS LCD 1.3 Inch 240×240 (4 unit, masing-masing 1 per locker)


* **Catu Daya Utama:** Adaptor Switching 12V 3A (1 unit)


* **Konverter Tegangan:** Step-down Buck Converter LM2596 (12V ke 5V, 1 unit)


* **Proteksi & Pendukung:**
* Dioda 1N4007 (8 unit — masing-masing 2 buah per jalur solenoid sebagai proteksi *flyback*)


* Fuse Holder + Fuse 5A (1 set — pengaman arus utama)


* Terminal Block / Screw Terminal 2 jalur (untuk pembagi daya)


* Kabel Body 0.75mm (7 warna) & Kabel Jumper secukupnya





---

## 2. Skema Pembagian Jalur Daya (*Power Management*)

Sistem ini menggunakan **sumber daya tunggal 12V** dari adaptor untuk menyuplai solenoid yang membutuhkan arus besar, yang kemudian diturunkan tegangannya untuk ESP32.

1. **Jalur Utama 12V:**
* Output Adaptor 12V 3A dihubungkan melewati **Fuse 5A** (sebagai pengaman korsleting) lalu masuk ke **Terminal Block utama**.
* Dari terminal block, daya 12V disalurkan ke:
* Port `COM` pada masing-masing 4 channel Modul Relay.
* Input `IN+` pada **Step-down Buck Converter LM2596**.




2. **Jalur Tegangan 5V (Logika & Mikrokontroler):**
* Step-down LM2596 dikalibrasi hingga menghasilkan output stabil **5V**.
* Output `OUT+` (5V) dihubungkan ke pin `VIN` atau `5V` pada ESP32, dan `OUT-` ke pin `GND` ESP32.
* Modul Relay 4 channel juga mendapat suplai daya 5V (`VCC` dan `GND`) dari ESP32 atau langsung dari output buck converter.



---

## 3. Skema Pengawatan (*Pin Mapping*) ESP32

### A. Kontrol Solenoid (via Relay 4 Channel)

Relay yang digunakan adalah tipe aktif LOW (relay akan aktif/menyalakan solenoid ketika mendapat sinyal `LOW` / `0` dari ESP32).

* **Relay Channel 1** $\leftarrow$ Terhubung ke Pin **GPIO 23** ESP32 (Mengontrol Locker 0)
* **Relay Channel 2** $\leftarrow$ Terhubung ke Pin **GPIO 22** ESP32 (Mengontrol Locker 1)
* **Relay Channel 3** $\leftarrow$ Terhubung ke Pin **GPIO 21** ESP32 (Mengontrol Locker 2)
* **Relay Channel 4** $\leftarrow$ Terhubung ke Pin **GPIO 19** ESP32 (Mengontrol Locker 3)

*Catatan Beban Solenoid:*

* Kutub positif (+) adaptor 12V masuk ke terminal `COM` relay, lalu dari terminal `NO` (Normally Open) relay dihubungkan ke kabel positif solenoid. Kutub negatif (-) solenoid langsung disambungkan kembali ke jalur negatif adaptor (GND bersama).
* **Proteksi Dioda (Flyback):** Pasang **2 buah dioda 1N4007** secara paralel berlawanan arah (*reverse-biased*) langsung di kaki terminal solenoid untuk meredam lonjakan tegangan induktif balik saat solenoid memutus arus, agar tidak merusak modul relay atau ESP32.

### B. Sensor Magnet / Reed Switch (Deteksi Pintu)

Sensor magnet bekerja sebagai saklar tertutup/terbuka (menggunakan resistor *Pull-up* internal ESP32).

* **Sensor Locker 0** $\leftarrow$ Terhubung ke Pin **GPIO 32** ESP32 (dan sisi lain ke `GND`)
* **Sensor Locker 1** $\leftarrow$ Terhubung ke Pin **GPIO 33** ESP32 (dan sisi lain ke `GND`)
* **Sensor Locker 2** $\leftarrow$ Terhubung ke Pin **GPIO 25** ESP32 (dan sisi lain ke `GND`)
* **Sensor Locker 3** $\leftarrow$ Terhubung ke Pin **GPIO 26** ESP32 (dan sisi lain ke `GND`)

### C. Layar TFT IPS 1.3" (Tampilan QR Dinamis per Locker)

Karena menggunakan protokol komunikasi **SPI**, layar TFT memerlukan jalur clock dan data bersama (kecuali pin *Chip Select* / CS yang dipisah per layar):

* **SCL / SCK** $\leftarrow$ Terhubung ke Pin **GPIO 18** ESP32 (Shared SPI Bus)
* **SDA / MOSI** $\leftarrow$ Terhubung ke Pin **GPIO 23 / 23 terbagi** atau pin MOSI standar ESP32 (**GPIO 23**)
* **RES (Reset)** $\leftarrow$ Terhubung ke Pin **GPIO 4** ESP32
* **DC (Data/Command)** $\leftarrow$ Terhubung ke Pin **GPIO 2** ESP32
* **CS (Chip Select - 4 buah untuk 4 layar):**
* Layar Locker 0 $\rightarrow$ Pin **GPIO 13**
* Layar Locker 1 $\rightarrow$ Pin **GPIO 14**
* Layar Locker 2 $\rightarrow$ Pin **GPIO 27**
* Layar Locker 3 $\rightarrow$ Pin **GPIO 12**


* **VCC & LED** $\rightarrow$ Disuplai dari jalur 3.3V / 5V ESP32 (sesuai spesifikasi modul TFT), **GND** ke `GND` bersama.

---

## 4. Panduan Perakitan & Keamanan Fisik (*Assembly Guidelines*)

1. **Tata Letak Komponen (*Enclosure Box*):** Tempatkan ESP32, modul relay, step-down converter, dan terminal block di dalam satu box/casing pelindung khusus yang diletakkan di bagian atas atau belakang lemari locker agar aman dari cipratan air dan jangkauan tangan bebas.
2. **Manajemen Kabel (*Cable Management*):** Gunakan kabel body 0.75mm dengan warna berbeda untuk jalur 12V (misal: Merah untuk positif, Hitam untuk negatif) agar tidak tertukar. Rapikan menggunakan *cable ties* dan bungkus setiap sambungan solder menggunakan *heat shrink tube* (selongsong bakar) untuk mencegah korsleting.
3. **Pemasangan Sensor & Solenoid di Lemari Tabitha 4 Pintu:**
* Pasang solenoid di bagian dinding samping/atas dalam masing-masing pintu locker dengan sekrup yang kokoh.
* Pasang sensor magnet (*reed switch*): bagian magnet permanen ditempel di daun pintu, dan bagian sensor kabel ditempel di kusen/rangka lemari yang sejajar, pastikan jarak deteksi renggangnya pas (< 1 cm) saat pintu ditutup rapat