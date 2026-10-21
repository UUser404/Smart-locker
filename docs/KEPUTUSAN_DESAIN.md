# Dokumen Keputusan Desain (Design Decisions) — Smart Locker IoT

Dokumen ini menjelaskan alasan teknis (rationale) di balik pemilihan arsitektur, teknologi, dan strategi pengembangan sistem, yang secara langsung diambil untuk menjawab batasan-batasan sistem (lihat dokumen Batasan Platform).

## 1. Arsitektur: Express sebagai Single Source of Truth

- **Keputusan:** Aplikasi Flutter (Petugas) dan Web (Pelanggan) **DILARANG** mengakses database Firestore secara langsung. Semua komunikasi data harus melewati Backend Express.
- **Alasan (Rationale):** Firestore Rules dikunci total (`allow read, write: if false`) demi keamanan. Express bertindak sebagai "gerbang" yang memvalidasi setiap request menggunakan JWT (untuk petugas) dan Device Token (untuk ESP32). Ini mencegah manipulasi data langsung dari _client_.
- **Kaitan dengan Batasan:** Menghindari kebocoran data sensitif (no HP pelanggan) dan mencegah _client_ memodifikasi status locker secara ilegal.

## 2. Teknologi: Polling HTTP `/sync` untuk ESP32

- **Keputusan:** ESP32 menggunakan protokol HTTP dengan mekanisme _Polling_ (mengirim request `/sync` tiap 2 detik), bukan WebSocket atau MQTT. Endpoint `/sync` menggabungkan pelaporan status pintu dan pengambilan perintah (unlock).
- **Alasan (Rationale):** WebSocket/MQTT butuh koneksi dua arah yang persisten. Karena backend berada di internet dan ESP32 di balik NAT (tanpa IP publik), komunikasi _push_ tidak mungkin dilakukan. Polling HTTP adalah cara paling sederhana dan andal.
- **Kaitan dengan Batasan:** Solusi mutlak untuk batasan NAT jaringan kampus. Penggabungan `/poll` dan `/report` menjadi `/sync` menghemat 50% _bandwidth_ dan meminimalisir beban server.

## 3. Optimasi Database: In-Memory Token Rotation

- **Keputusan:** Token QR dinamis yang berganti tiap 5 detik **TIDAK** disimpan ke Firestore, melainkan disimpan di RAM (In-Memory Store) pada backend Express.
- **Alasan (Rationale):** Menulis token ke Firestore setiap 5 detik untuk 2 locker akan menghabiskan 34.560 _writes_/hari. Ini melebihi batas gratis Firestore (20.000/hari). Dengan menyimpannya di RAM, _writes_ database turun drastis (0 writes untuk rotasi), sehingga sistem tidak akan pernah kena "Quota Exceeded".
- **Kaitan dengan Batasan:** Solusi langsung untuk menaklukkan batas kuota Firestore.

## 4. Keamanan: Dua Lapis Autentikasi (JWT & Device Token)

- **Keputusan:** Admin/Petugas menggunakan JWT (Bearer Token), sedangkan ESP32 menggunakan _Device Token_ (header `X-Device-Token` yang unik per controller).
- **Alasan (Rationale):** Endpoint admin tidak boleh diakses sembarang orang (mencegah peretasan dashboard). Endpoint firmware juga tidak boleh diakses sembarangan (mencegah orang iseng menyuruh ESP32 membuka pintu locker).
- **Kaitan dengan Batasan:** Mengamankan komunikasi IoT dari penyalahgunaan tanpa membebani perangkat dengan algoritma kriptografi yang berat.

## 5. UI/UX: Desain QR Dinamis (5 Detik vs 60 Detik)

- **Keputusan:** QR di layar TFT locker berubah setiap 5 detik. Namun, token tersebut tetap _valid_ di backend selama 60 detik. Token dibekukan (tidak dirotasi) jika locker sedang disewa.
- **Alasan (Rationale):** Rotasi 5 detik mencegah _screenshot_ QR dari jarak jauh. Validitas 60 detik memberikan waktu yang wajar bagi pelanggan untuk mengisi form nama/no HP. Pembekuan saat `occupied` memungkinkan pelanggan memindai ulang QR yang sama saat ingin mengambil barang.
- **Kaitan dengan Batasan:** Mengatasi batasan keamanan fisik (jarak) dan batasan _usability_ (waktu pengisian form).

## 6. Strategi Notifikasi: Anti-Alarm Fatigue

- **Keputusan:** Notifikasi bahaya `needs_attention` hanya dikirim ke petugas maksimal **1x per 10 menit** per locker, dengan menerapkan _Collapse Key_ dan _Time To Live_ (TTL) 30 menit.
- **Alasan (Rationale):** Petugas bisa mematikan notifikasi jika dibombardir pesan berulang (alarm fatigue), sehingga bahaya yang sebenarnya malah terlewat. Jeda 10 menit menjaga notifikasi tetap "sakral".
- **Kaitan dengan Batasan:** Mengatasi batasan platform Android (aggressive battery saver) agar aplikasi tidak dibunuh OS akibat terlalu sering membangunkan HP.
