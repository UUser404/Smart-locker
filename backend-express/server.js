const express = require("express");
const cors = require("cors");
const { initializeApp, cert } = require("firebase-admin/app");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const crypto = require("crypto");

// ========== INISIALISASI FIREBASE ADMIN ==========
let serviceAccount;

if (process.env.FIREBASE_SERVICE_ACCOUNT_BASE64) {
  serviceAccount = JSON.parse(
    Buffer.from(process.env.FIREBASE_SERVICE_ACCOUNT_BASE64, "base64").toString(
      "utf8",
    ),
  );
} else if (process.env.FIREBASE_SERVICE_ACCOUNT) {
  serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);
} else {
  serviceAccount = require("./serviceAccountKey.json");
}

initializeApp({
  credential: cert(serviceAccount),
  projectId: serviceAccount.project_id,
});

const db = getFirestore();
const app = express();

app.use(cors());
app.use(express.json());

// ========== HEALTH CHECK ==========
app.get("/", (req, res) => {
  res.json({ status: "ok", message: "Smart Locker backend jalan" });
});

// ========== SEWA LOCKER ==========
app.post("/rentLocker", async (req, res) => {
  const { lockerId, qrToken, nama, noHp } = req.body;

  if (!lockerId || !qrToken || !nama || !noHp) {
    return res
      .status(400)
      .json({ status: "error", message: "Data kurang lengkap" });
  }

  const lockerRef = db.collection("lockers").doc(lockerId);

  try {
    const result = await db.runTransaction(async (tx) => {
      const lockerDoc = await tx.get(lockerRef);
      if (!lockerDoc.exists) throw new Error("LOCKER_NOT_FOUND");

      const locker = lockerDoc.data();

      if (locker.status !== "empty") throw new Error("LOCKER_NOT_EMPTY");
      if (!locker.qrTokenGeneratedAt) throw new Error("QR_TOKEN_TIME_MISSING");

      const tokenAgeMs = Date.now() - locker.qrTokenGeneratedAt.toMillis();
      if (locker.currentQrToken !== qrToken || tokenAgeMs > 60000) {
        throw new Error("TOKEN_INVALID_OR_EXPIRED");
      }

      const uniqueCode = crypto.randomBytes(4).toString("hex").toUpperCase();
      const uniqueCodeHash = crypto
        .createHash("sha256")
        .update(uniqueCode)
        .digest("hex");

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
    const code = err.message;
    const httpStatus = code === "LOCKER_NOT_FOUND" ? 404 : 409;
    res.status(httpStatus).json({ status: "error", message: code });
  }
});

// ========== LANJUT SEWA / AKHIRI SEWA ==========
app.post("/returnLocker", async (req, res) => {
  const { lockerId, uniqueCode, action = "end" } = req.body;

  if (!lockerId || !uniqueCode) {
    return res
      .status(400)
      .json({ status: "error", message: "Data kurang lengkap" });
  }

  if (!["continue", "end"].includes(action)) {
    return res.status(400).json({ status: "error", message: "ACTION_INVALID" });
  }

  const lockerRef = db.collection("lockers").doc(lockerId);

  try {
    const result = await db.runTransaction(async (tx) => {
      const lockerDoc = await tx.get(lockerRef);
      if (!lockerDoc.exists) throw new Error("LOCKER_NOT_FOUND");

      const locker = lockerDoc.data();

      if (locker.status !== "occupied") throw new Error("LOCKER_NOT_OCCUPIED");
      if (!locker.currentRentalId) throw new Error("NO_ACTIVE_RENTAL");

      const rentalRef = db.collection("rentals").doc(locker.currentRentalId);
      const rentalDoc = await tx.get(rentalRef);
      if (!rentalDoc.exists) throw new Error("RENTAL_NOT_FOUND");

      const rental = rentalDoc.data();

      const inputHash = crypto
        .createHash("sha256")
        .update(String(uniqueCode).toUpperCase())
        .digest("hex");

      if (inputHash !== rental.uniqueCodeHash) {
        throw new Error("INVALID_UNIQUE_CODE");
      }

      if (action === "continue") {
        tx.update(lockerRef, { pendingCommand: "unlock" });
        return {
          rentalId: rentalRef.id,
          message: "Locker dibuka lagi, sesi masih berjalan",
        };
      }

      const nowMs = Date.now();
      const startedAtMs = rental.startedAt
        ? rental.startedAt.toMillis()
        : nowMs;
      const totalDurationSeconds = Math.max(
        0,
        Math.floor((nowMs - startedAtMs) / 1000),
      );

      tx.update(rentalRef, {
        status: "completed",
        endedAt: FieldValue.serverTimestamp(),
        totalDurationSeconds,
      });

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
        message: "Locker berhasil dikembalikan",
      };
    });

    res.status(200).json({ status: "ok", ...result });
  } catch (err) {
    const code = err.message;
    const httpStatus = code === "LOCKER_NOT_FOUND" ? 404 : 409;
    res.status(httpStatus).json({ status: "error", message: code });
  }
});

// ========== START SERVER ==========
const PORT = process.env.PORT || 3000;
app.listen(PORT, () => console.log(`Server jalan di port ${PORT}`));
