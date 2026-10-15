# Penambahan Endpoint — Login & Laporan Admin

> **Status**: ✅ **SUDAH DIIMPLEMENTASI & LIVE** di production.
>
> - **Tanggal implementasi**: Sesi Batch 3 & Batch 5 (lihat `firmware/DOKUMENTASI_PROGRESS_BACKEND.md`)
> - **Deploy**: `https://smart-locker-backend-a2ck.onrender.com`
> - **Teruji**: End-to-end dari app Flutter petugas & admin
> - **Kontrak resmi**: Sudah masuk `docs/API.md` bagian 10

---

## 1. POST /api/auth/login

Autentikasi petugas/admin. Return JWT token untuk akses endpoint admin selanjutnya.

### Request

```http
POST /api/auth/login
Content-Type: application/json
```

```json
{
  "username": "petugas1",
  "password": "petugas123"
}
```

### Response Sukses (200)

```json
{
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "role": "petugas",
  "nama": "Budi Santoso"
}
```

- `role` cuma dua kemungkinan: `"admin"` atau `"petugas"`
- `token` adalah JWT dengan expiry 7 hari, tanpa refresh token

### Response Gagal (401)

```json
{
  "status": "error",
  "message": "Username atau password salah"
}
```

> ⚠️ **Catatan keamanan:** Pesan error sengaja generik — tidak membedakan "user tidak ada" vs "password salah" (mencegah _user enumeration_).

### Response Gagal (400)

```json
{
  "status": "error",
  "message": "Data kurang lengkap"
}
```

### Detail Implementasi

| Aspek                  | Nilai                                                            |
| :--------------------- | :--------------------------------------------------------------- |
| **Hashing password**   | `bcrypt` (cost 10)                                               |
| **Token**              | JWT, expiry 7 hari                                               |
| **Token secret**       | Env variable `JWT_SECRET` di Render                              |
| **Akun dibuat**        | Manual via seed (`seedPetugas.js`) — tidak ada endpoint register |
| **Kolom di Firestore** | `petugas/{username}` (flat, bukan subcollection)                 |
| **Field user**         | `nama`, `username`, `role`, `passwordHash`                       |

### Keputusan Desain (Final)

- ✅ **Akun admin/petugas dibuat manual di database (seed)** — tidak ada endpoint register. Alasan: sistem internal untuk kampus, jumlah user sedikit, tidak butuh registrasi mandiri.
- ✅ **JWT dengan expiry 7 hari, tanpa refresh token** — cukup untuk skala prototipe kampus, simpel di app.
- ✅ **Bcrypt cost 10** — praktik baik untuk hashing password.

### Handler di Backend

File: `backend-express/src/routes/auth.js`

```javascript
router.post("/login", async (req, res) => {
  const { username, password } = req.body;
  // ... validasi
  const doc = await db.collection("petugas").doc(username).get();
  if (!doc.exists) {
    /* 401 */
  }
  const petugas = doc.data();
  const ok = await verifyPassword(password, petugas.passwordHash);
  if (!ok) {
    /* 401 */
  }
  const token = generateToken({
    username,
    role: petugas.role,
    nama: petugas.nama,
  });
  return res
    .status(200)
    .json({ token, role: petugas.role, nama: petugas.nama });
});
```

### Konsumsi di App Flutter

File: `mprojectapp/lib/services/api_service.dart`

```dart
Future<AuthSession> login({required String username, required String password}) async {
  final res = await _client.post(_uri('/auth/login'), ...);
  // ... error handling
  final session = AuthSession.fromJson(jsonDecode(res.body));
  setToken(session.token);   // auto-attach untuk request berikutnya
  return session;
}
```

---

## 2. GET /api/admin/reports/rentals

Laporan sesi sewa untuk dashboard admin.

### Request

```http
GET /api/admin/reports/rentals
Authorization: Bearer <token_dari_login>
```

- **Role yang boleh**: `admin` saja (`petugas` tidak boleh)
- **Token**: Didapat dari `/auth/login`

### Response Sukses (200)

```json
{
  "stats": {
    "total_rentals": 9,
    "avg_duration_seconds": 593,
    "busiest_locker_id": "locker_01"
  },
  "rentals": [
    {
      "rental_id": "rnt_2001",
      "locker_id": "locker_01",
      "nama": "Budi Santoso",
      "no_hp": "0812****89",
      "started_at": "2026-09-23T05:00:00Z",
      "ended_at": "2026-09-23T05:18:00Z",
      "total_duration_seconds": 1080,
      "status": "completed"
    }
  ]
}
```

- **Sesi yang masih aktif**: `ended_at` dan `total_duration_seconds` bernilai `null`, `status = "active"`
- **Status kemungkinan**: `"active"` | `"completed"` | `"expired"`

### Response Gagal

| HTTP    | Body                                           | Kondisi                           |
| :------ | :--------------------------------------------- | :-------------------------------- |
| **401** | `{"status":"error","message":"MISSING_TOKEN"}` | Tidak ada header Authorization    |
| **401** | `{"status":"error","message":"INVALID_TOKEN"}` | Token invalid/expired             |
| **403** | `{"status":"error","message":"FORBIDDEN"}`     | Token valid tapi role bukan admin |
| **500** | `{"status":"error","message":"SERVER_ERROR"}`  | Error backend                     |

### Detail Implementasi

| Aspek              | Nilai                                       |
| :----------------- | :------------------------------------------ |
| **Proteksi**       | `requireAuth` + `requireRole("admin")`      |
| **Source data**    | Firestore collection `rentals`              |
| **Service**        | `reportService.js` (`getRentalsReport()`)   |
| **Masking no_hp**  | ✅ Ya — di-mask sebagian, mis. `0812****89` |
| **Filter tanggal** | ❌ Belum ada — semua riwayat ditampilkan    |

### Keputusan Desain (Final)

- ✅ **Filter tanggal**: TIDAK ADA untuk sekarang — semua riwayat ditampilkan. Alasan: prototipe kampus, jumlah rental masih sedikit. Bisa ditambah nanti kalau perlu (`?from=&to=`).
- ✅ **`no_hp` di-mask sebagian** — untuk privasi. Format mask: 4 digit awal + `****` + 2 digit akhir. Contoh: `0812****89`.
- ✅ **`busiest_locker_id` bisa null** — kalau belum ada rental. App Flutter sudah handle ini (`nullable`).

### Handler di Backend

File: `backend-express/src/routes/admin.js`

```javascript
router.get(
  "/reports/rentals",
  requireAuth,
  requireRole("admin"),
  async (req, res) => {
    try {
      const result = await getRentalsReport();
      return res.status(200).json(result);
    } catch (err) {
      /* 500 */
    }
  },
);
```

File: `backend-express/src/services/reportService.js` — logic komputasi stats + masking `no_hp`.

### Konsumsi di App Flutter

File: `mprojectapp/lib/services/api_service.dart`

```dart
Future<(RentalStats, List<RentalRecord>)> fetchRentalReports() async {
  final res = await _client.get(_uri('/admin/reports/rentals'), headers: _headers(json: false));
  // ... error handling
  final body = jsonDecode(res.body) as Map<String, dynamic>;
  final stats = RentalStats.fromJson(body['stats']);
  final rentals = (body['rentals'] as List).map((e) => RentalRecord.fromJson(e)).toList();
  return (stats, rentals);
}
```

---

## 3. Proteksi Endpoint Admin dengan JWT

Update dari proposal awal: Sekarang semua endpoint admin dilindungi JWT.

### Endpoint yang Diproteksi

| Endpoint                          | Method | Role           | Status                           |
| :-------------------------------- | :----- | :------------- | :------------------------------- |
| `/api/admin/lockers`              | GET    | admin, petugas | ✅ Protected                     |
| `/api/admin/lockers/{id}/resolve` | POST   | admin, petugas | ✅ Protected                     |
| `/api/admin/reports/rentals`      | GET    | admin only     | ✅ Protected                     |
| `/api/admin/register-device`      | POST   | —              | ❌ Tanpa auth (first-time setup) |

### Cara Pakai

Semua request ke endpoint admin wajib sertakan header:

```http
Authorization: Bearer <token_dari_login>
```

### Response Error

| HTTP    | Body                                           | Kondisi                            |
| :------ | :--------------------------------------------- | :--------------------------------- |
| **401** | `{"status":"error","message":"MISSING_TOKEN"}` | Tidak ada header Authorization     |
| **401** | `{"status":"error","message":"INVALID_TOKEN"}` | Token invalid/expired              |
| **403** | `{"status":"error","message":"FORBIDDEN"}`     | Token valid tapi role tidak sesuai |

### Handler di Backend

File: `backend-express/src/middleware/authMiddleware.js`

```javascript
function requireAuth(req, res, next) {
  const auth = req.headers.authorization;
  if (!auth || !auth.startsWith("Bearer ")) {
    return res.status(401).json({ status: "error", message: "MISSING_TOKEN" });
  }
  const token = auth.slice(7);
  try {
    req.user = verifyToken(token);
    next();
  } catch (err) {
    return res.status(401).json({ status: "error", message: "INVALID_TOKEN" });
  }
}

function requireRole(...roles) {
  return (req, res, next) => {
    if (!req.user || !roles.includes(req.user.role)) {
      return res.status(403).json({ status: "error", message: "FORBIDDEN" });
    }
    next();
  };
}
```

### Konsumsi di App Flutter

File: `mprojectapp/lib/services/api_service.dart`

Setiap method yang hit endpoint admin auto-attach JWT:

```dart
Map<String, String> _headers({bool json = true}) {
  final h = <String, String>{};
  if (json) h['Content-Type'] = 'application/json';
  if (_token != null && _token!.isNotEmpty) {
    h['Authorization'] = 'Bearer $_token';
  }
  return h;
}
```

---

## 4. Dampak ke Endpoint Existing

**Kesimpulan**: ✅ Tidak ada _breaking change_. Endpoint yang sudah ada tetap sama, hanya ditambah proteksi JWT.

### Ringkasan Status

| #   | Yang Dulunya "Proposal"          | Status Sekarang |
| :-- | :------------------------------- | :-------------- |
| 1   | `POST /api/auth/login`           | ✅ Live         |
| 2   | `GET /api/admin/reports/rentals` | ✅ Live         |
| 3   | Proteksi JWT di endpoint admin   | ✅ Live         |

### Yang Berbeda dari Proposal Awal

| Aspek                        | Proposal Awal           | Implementasi Final                    |
| :--------------------------- | :---------------------- | :------------------------------------ |
| `no_hp` di reports           | ❓ Belum diputuskan     | ✅ Di-mask (`0812****89`)             |
| Filter tanggal               | ❓ Belum diputuskan     | ❌ Tidak ada (semua riwayat)          |
| Token expiry                 | ❓ Belum diputuskan     | ✅ 7 hari JWT, tanpa refresh          |
| Akun dibuat                  | ❓ Manual atau register | ✅ Manual via seed                    |
| Masking nama field           | —                       | ✅ Sudah handle di `reportService.js` |
| `busiest_locker_id` nullable | —                       | ✅ Backend kadang kirim `null`        |

---

## 5. Testing Status

| #   | Test Case                                | Status | Tanggal     |
| :-- | :--------------------------------------- | :----- | :---------- |
| 1   | Login admin (`admin`/`admin123`)         | ✅     | Batch 3     |
| 2   | Login petugas (`petugas1`/`petugas123`)  | ✅     | Batch 3     |
| 3   | Login dengan password salah → 401        | ✅     | Batch 3     |
| 4   | Fetch reports tanpa token → 401          | ✅     | Batch 5     |
| 5   | Fetch reports dengan token petugas → 403 | ✅     | Batch 5     |
| 6   | Fetch reports dengan token admin → 200   | ✅     | Batch 5     |
| 7   | Masking `no_hp` di response              | ✅     | Batch 5     |
| 8   | App Flutter consume endpoint             | ✅     | 14 Okt 2026 |
| 9   | FCM notification end-to-end              | ✅     | 14 Okt 2026 |

_Lihat `docs/DOKUMENTASI_TESTING_FCM.md` untuk detail testing FCM._

---

## 6. Referensi

| Dokumen / File                                     | Deskripsi                    |
| :------------------------------------------------- | :--------------------------- |
| `docs/API.md` (bagian 10)                          | Kontrak resmi endpoint admin |
| `firmware/DOKUMENTASI_PROGRESS_BACKEND.md`         | Progress backend (Batch 1-5) |
| `docs/DOKUMENTASI_TESTING_FCM.md`                  | Testing FCM end-to-end       |
| `backend-express/src/routes/auth.js`               | Handler login                |
| `backend-express/src/routes/admin.js`              | Handler admin endpoints      |
| `backend-express/src/services/reportService.js`    | Logic reports + masking      |
| `backend-express/src/middleware/authMiddleware.js` | JWT middleware               |
| `mprojectapp/lib/services/api_service.dart`        | Konsumsi API dari Flutter    |

---

## 7. Changelog

| Tanggal             | Perubahan                                             |
| :------------------ | :---------------------------------------------------- |
| **Awal (proposal)** | Dokumen ini dibuat sebagai proposal untuk Galuh       |
| **Batch 3**         | Login endpoint diimplementasi & di-deploy             |
| **Batch 5**         | Reports endpoint diimplementasi & di-deploy           |
| **14 Okt 2026**     | Dokumen di-update: dari "proposal" jadi "implemented" |

> **Status akhir**: ✅ Semua endpoint di dokumen ini sudah LIVE dan teruji.
