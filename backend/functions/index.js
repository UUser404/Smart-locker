const { onRequest } = require("firebase-functions/v2/https");
const { setGlobalOptions } = require("firebase-functions/v2");
const admin = require("firebase-admin");
const { FieldValue } = require("firebase-admin/firestore");
const crypto = require("crypto");

admin.initializeApp();
const db = admin.firestore();

// Atur region secara global untuk semua fungsi
setGlobalOptions({ region: "asia-southeast2" });

// ==========================================
// 1. FUNGSI SEWA LOKER (rentLocker)
// ==========================================
exports.rentLocker = onRequest(async (req, res) => {
  const { lockerId, qrToken, nama, noHp } = req.body;
  const lockerRef = db.collection("lockers").doc(lockerId);

  try {
    const result = await db.runTransaction(async (tx) => {
      const lockerDoc = await tx.get(lockerRef);
      if (!lockerDoc.exists) throw new Error("LOCKER_NOT_FOUND");

      const locker = lockerDoc.data();

      // 1. Locker harus masih kosong
      if (locker.status !== "empty") throw new Error("LOCKER_NOT_EMPTY");

      // 2. Token QR harus cocok & belum lewat 60 detik
      const tokenAgeMs = Date.now() - locker.qrTokenGeneratedAt.toMillis();
      if (locker.currentQrToken !== qrToken || tokenAgeMs > 60000) {
        throw new Error("TOKEN_INVALID_OR_EXPIRED");
      }

      // 3. Generate kode unik — yang disimpan cuma HASH-nya
      const uniqueCode = crypto.randomBytes(4).toString("hex").toUpperCase();
      const uniqueCodeHash = crypto
        .createHash("sha256")
        .update(uniqueCode)
        .digest("hex");

      // 4. Catat sesi sewa baru
      const rentalRef = db.collection("rentals").doc();
      tx.set(rentalRef, {
        lockerId,
        nama,
        noHp,
        uniqueCodeHash,
        status: "active",
        startedAt: FieldValue.serverTimestamp(),
        endedAt: null,
        totalDurationSeconds: null,
      });

      // 5. Kunci locker: freeze QR, tandai occupied, titip perintah unlock
      tx.update(lockerRef, {
        status: "occupied",
        qrTokenFrozen: true,
        currentRentalId: rentalRef.id,
        unlockedSince: FieldValue.serverTimestamp(),
        pendingCommand: "unlock",
      });

      return { rentalId: rentalRef.id, uniqueCode };
    });

    res.status(200).json({ status: "ok", ...result });
  } catch (err) {
    res.status(409).json({ status: "error", message: err.message });
  }
});

// ==========================================
// 2. FUNGSI PENGEMBALIAN LOKER (returnLocker)
// ==========================================
exports.returnLocker = onRequest(async (req, res) => {
  const { lockerId, uniqueCode } = req.body;
  const lockerRef = db.collection("lockers").doc(lockerId);

  try {
    const result = await db.runTransaction(async (tx) => {
      const lockerDoc = await tx.get(lockerRef);
      if (!lockerDoc.exists) throw new Error("LOCKER_NOT_FOUND");

      const locker = lockerDoc.data();

      // 1. Pastikan locker sedang terisi
      if (locker.status !== "occupied") throw new Error("LOCKER_NOT_OCCUPIED");
      if (!locker.currentRentalId) throw new Error("NO_ACTIVE_RENTAL");

      // 2. Ambil data rental aktif
      const rentalRef = db.collection("rentals").doc(locker.currentRentalId);
      const rentalDoc = await tx.get(rentalRef);
      if (!rentalDoc.exists) throw new Error("RENTAL_NOT_FOUND");

      const rental = rentalDoc.data();

      // 3. Verifikasi Kode Unik
      const inputHash = crypto
        .createHash("sha256")
        .update(uniqueCode)
        .digest("hex");

      if (inputHash !== rental.uniqueCodeHash) {
        throw new Error("INVALID_UNIQUE_CODE");
      }

      // 4. Hitung durasi sewa dalam detik
      const nowMs = Date.now();
      const startedAtMs = rental.startedAt
        ? rental.startedAt.toMillis()
        : nowMs;
      const totalDurationSeconds = Math.max(
        0,
        Math.floor((nowMs - startedAtMs) / 1000),
      );

      // 5. Update transaksi rental menjadi completed
      tx.update(rentalRef, {
        status: "completed",
        endedAt: FieldValue.serverTimestamp(),
        totalDurationSeconds,
      });

      // 6. Kembalikan status locker menjadi empty & kirim perintah unlock
      tx.update(lockerRef, {
        status: "empty",
        currentRentalId: null,
        qrTokenFrozen: false,
        unlockedSince: FieldValue.serverTimestamp(),
        pendingCommand: "unlock",
      });

      return {
        rentalId: rentalRef.id,
        totalDurationSeconds,
        message: "Locker successfully returned",
      };
    });

    res.status(200).json({ status: "ok", ...result });
  } catch (err) {
    res.status(409).json({ status: "error", message: err.message });
  }
});
