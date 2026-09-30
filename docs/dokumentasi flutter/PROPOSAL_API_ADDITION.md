# Proposal Penambahan Endpoint — Login & Laporan Admin

> Belum ada di `docs/API.md`. App Flutter sudah dibangun mengasumsikan
> kontrak di bawah ini (pakai mock data sementara). Tolong konfirmasi ke
> Galuh sebelum backend beneran diimplementasikan, biar sinkron.

---

## POST /api/auth/login

Body:
```json
{ "username": "petugas1", "password": "rahasia123" }
```

Response sukses (200):
```json
{
  "token": "jwt-atau-token-sesi",
  "role": "admin",
  "nama": "Budi Santoso"
}
```
`role` cuma dua kemungkinan: `"admin"` atau `"petugas"`.

Response gagal (401):
```json
{ "status": "error", "message": "Username atau password salah" }
```

**Pertanyaan buat Galuh:**
- Akun admin/petugas dibuat manual di database (seed), atau perlu endpoint register juga?
- Token perlu expiry/refresh, atau untuk skala prototipe cukup token statis per user?

---

## GET /api/admin/reports/rentals

Perlu header auth (token dari login), role admin saja yang boleh akses.

Response (200):
```json
{
  "stats": {
    "total_rentals": 3,
    "avg_duration_seconds": 840,
    "busiest_locker_id": "locker_02"
  },
  "rentals": [
    {
      "rental_id": "rnt_2001",
      "locker_id": "locker_01",
      "nama": "Budi Santoso",
      "no_hp": "0812xxxxxx01",
      "started_at": "2026-09-23T05:00:00Z",
      "ended_at": "2026-09-23T05:18:00Z",
      "total_duration_seconds": 1080
    }
  ]
}
```
Sesi yang masih aktif: `ended_at` dan `total_duration_seconds` = `null`.

**Pertanyaan buat Galuh:**
- Perlu filter tanggal (`?from=&to=`)? Untuk prototipe kampus mungkin cukup tampilkan semua riwayat tanpa filter dulu.
- `no_hp` ditampilkan penuh atau di-mask sebagian (privasi) di laporan ini?

---

## Dampak ke endpoint yang sudah ada

Tidak ada — 3 endpoint di bagian 10 `API.md` (`/admin/lockers`, `/admin/lockers/{id}/resolve`, `/admin/register-device`) tetap sama. Cuma perlu ditambah requirement: endpoint-endpoint itu sekarang idealnya juga divalidasi pakai token dari login (role petugas atau admin), bukan diakses bebas seperti sekarang.
