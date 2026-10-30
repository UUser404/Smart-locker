# 🛠️ Laporan Perbaikan Bug: QR Token Gagal Berputar Kembali (Desinkronisasi State)

> **Tanggal:** 30 Oktober 2026  
> **Modul:** Backend (Express) & Firmware (ESP32)  
> **Tingkat Keparahan:** 🔴 **High** _(Sistem gagal memproses sewa baru karena QR dinamis berhenti berputar)_

---

## 1. Deskripsi Masalah (Symptom)

Setelah pelanggan menyelesaikan sesi penyewaan (menutup pintu locker dan status kembali menjadi kosong), layar TFT locker tetap menampilkan QR Code yang sama (beku/frozen).

Scheduler backend (`qrTokenRotatorService`) tidak lagi merotasi token baru untuk locker tersebut, sehingga pelanggan berikutnya tidak bisa melakukan penyewaan.

> **Catatan:** Di sisi Database (Firestore), flag `qrTokenFrozen` sudah berhasil berubah menjadi `false`, namun perilaku sistem tetap tidak berubah.

---

## 2. Analisis Akar Masalah (Root Cause)

Bug ini terjadi akibat **Desinkronisasi State** antara Database (Firestore) dan Cache Memori (_In-Memory Store_).

1. **Optimasi Quota:** Untuk mencegah _Quota Exceeded_ Firestore, proses rotasi token dipindahkan dari database ke RAM (_In-Memory Store_). Rotator hanya membaca status `frozen` dari RAM.
2. **Race Condition pada `/sync`:** Fungsi `handleDoorClosed` di `firmware.js` menerima data locker dari snapshot request `/sync`. Jika request `/access` (Akhiri Sewa) dan request `/sync` (Pintu Tertutup) datang hampir bersamaan, snapshot `/sync` mungkin belum melihat flag `pendingEnd: true`.
3. **Lupa Update Cache:** Karena _race condition_ tersebut (atau alur logika yang terlewat), saat sesi berhasil diselesaikan, kode hanya melakukan update ke Firestore (`qrTokenFrozen: false`) tanpa memperbarui variabel di RAM (`tokenStore.setFrozen(lockerId, false)`).

**Dampak:** Rotator terus membaca status di RAM yang masih menganggap locker tersebut _frozen_ (dibekukan).

---

## 3. Langkah Perbaikan (Resolution)

Perbaikan dilakukan pada file `backend-express/src/routes/firmware.js` di dalam fungsi `handleDoorClosed`:

1. **Ambil Data Terbaru (Fix Race Condition):** Sebelum memproses finalisasi, fungsi tidak lagi menggunakan data dari parameter locker, melainkan melakukan _fetch_ ulang data terbaru langsung dari Firestore (`await lockerRef.get()`).
2. **Sinkronisasi Cache:** Menambahkan trigger untuk memperbarui _In-Memory Store_ tepat setelah transaksi Firestore selesai.

### Kode Perbaikan

```javascript
// Di dalam handleDoorClosed()
const latestDoc = await lockerRef.get(); // Fetch data terbaru
const latestLocker = latestDoc.data();

if (latestLocker.pendingEnd === true && latestLocker.currentRentalId) {
  // ... (proses finalisasi rental & update Firestore) ...

  // Sinkronisasi ke In-Memory Store
  tokenStore.setStatus(lockerId, "empty");
  tokenStore.setFrozen(lockerId, false); // <-- Kunci perbaikan

  console.log(`[tokenStore] ${lockerId} di-unfreeze (QR berputar lagi)`);
}
```

---

## 4. Pengujian (Testing)

Pengujian dilakukan menggunakan **Thunder Client** untuk mensimulasikan alur IoT:

1. **Rent:** Menyewa locker (status menjadi `occupied`).
2. **Sync:** Mengecek status, token QR tetap sama (`frozen`).
3. **Access (End):** Mengakhiri sewa via kode unik.
4. **Sync (Open -> Close):** Menembak endpoint `/sync` untuk mensimulasikan pintu dibuka lalu ditutup.

### Hasil Log Terminal Backend

```text
[sync] locker_01: pintu tertutup
[sync] sesi RzkixrMTAU29yG6Et1 selesai, 170s
[tokenStore] locker_01 di-unfreeze (QR berputar lagi)
```

Setelah jeda 5 detik, request `/sync` kembali menampilkan token yang berbeda, membuktikan rotasi QR telah berjalan normal kembali.

---

## 5. Pembersihan Tambahan (Cleanup)

Ditemukan juga _stale data_ di mana sistem masih memuat 4 locker (`locker_01` s/d `locker_04`).

Sistem dibersihkan dengan:

- Menghapus `locker_03` & `locker_04` dari Firestore Console.
- Mengubah `seed.js` agar hanya melakukan _seed_ untuk 2 locker ke depannya.

---

## 6. Pelajaran yang Diambil (Lesson Learned)

- ⚖️ **Trade-off Caching:** Menggunakan _In-Memory Cache_ (RAM) sangat baik untuk performa dan penghematan biaya, tetapi menuntut kedisiplinan tinggi untuk selalu menyinkronkan data setiap kali ada perubahan state (_Create/Update/Delete_) di database utama.
- 🔄 **Race Condition Handling:** Selalu lakukan _double-check_ atau _re-fetch_ data langsung dari _source of truth_ (Firestore) sebelum melakukan aksi krusial (seperti finalisasi sesi), jangan hanya mengandalkan data payload yang dikirim oleh client/gateway.
