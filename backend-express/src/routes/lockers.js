const express = require("express");
const {
  db
} = require("../firebase");
const {
  generateUniqueCode,
  hashCode,
  verifyCode
} = require("../services/uniqueCodeService");
const {
  isTokenValid
} = require("../services/qrTokenService");
const {
  checkLock,
  recordFailedAttempt,
  resetAttempts,
} = require("../services/rateLimiterService");

const router = express.Router();

// GET /api/lockers/:id/status?token=xxx
router.get("/:id/status", async (req, res) => {
  const {
    id: lockerId
  } = req.params;
  const {
    token
  } = req.query;

  if (!token) {
    return res.status(400).json({
      status: "error",
      code: "TOKEN_MISSING",
      message: "Token QR wajib disertakan",
    });
  }

  try {
    const lockerDoc = await db.collection("lockers").doc(lockerId).get();
    if (!lockerDoc.exists) {
      return res
        .status(404)
        .json({
          status: "error",
          message: "LOCKER_NOT_FOUND"
        });
    }

    const locker = lockerDoc.data();
    if (!isTokenValid(locker.qrTokens, token)) {
      return res.status(400).json({
        status: "error",
        code: "TOKEN_EXPIRED",
        message: "QR sudah kedaluwarsa, silakan scan ulang",
      });
    }

    return res.status(200).json({
      locker_id: lockerId,
      status: locker.status,
    });
  } catch (err) {
    console.error(err);
    return res.status(500).json({
      status: "error",
      message: "SERVER_ERROR"
    });
  }
});

// POST /api/lockers/:id/rent
router.post("/:id/rent", async (req, res) => {
  const {
    id: lockerId
  } = req.params;
  const {
    nama,
    no_hp,
    token
  } = req.body;

  if (!nama || !no_hp || !token) {
    return res
      .status(400)
      .json({
        status: "error",
        message: "Data kurang lengkap"
      });
  }

  const lockerRef = db.collection("lockers").doc(lockerId);

  try {
    const result = await db.runTransaction(async (tx) => {
      const lockerDoc = await tx.get(lockerRef);
      if (!lockerDoc.exists) throw new Error("LOCKER_NOT_FOUND");

      const locker = lockerDoc.data();

      if (locker.status !== "empty") throw new Error("LOCKER_NOT_EMPTY");
      if (!isTokenValid(locker.qrTokens, token))
        throw new Error("TOKEN_EXPIRED");

      const uniqueCode = generateUniqueCode();
      const uniqueCodeHash = hashCode(uniqueCode);

      const rentalRef = db.collection("rentals").doc();
      const startedAt = new Date();

      tx.set(rentalRef, {
        rentalId: rentalRef.id,
        lockerId,
        nama,
        noHp: no_hp,
        uniqueCodeHash,
        status: "active",
        startedAt,
        endedAt: null,
        totalDurationSeconds: null,
        accessAction: null,
        lastAccessAt: null,
      });

      tx.update(lockerRef, {
        status: "occupied",
        currentRentalId: rentalRef.id,
        qrTokenFrozen: true,
        unlockedSince: startedAt,
        pendingCommand: "unlock",
        pendingEnd: false,
      });

      return {
        rental_id: rentalRef.id,
        unique_code: uniqueCode,
        started_at: startedAt.toISOString(),
      };
    });

    return res.status(200).json({
      status: "ok",
      ...result
    });
  } catch (err) {
    const code = err.message;

    if (code === "LOCKER_NOT_FOUND") {
      return res.status(404).json({
        status: "error",
        message: code
      });
    }
    if (code === "TOKEN_EXPIRED") {
      return res.status(400).json({
        status: "error",
        code: "TOKEN_EXPIRED",
        message: "QR sudah kedaluwarsa, silakan scan ulang",
      });
    }
    if (code === "LOCKER_NOT_EMPTY") {
      return res
        .status(409)
        .json({
          status: "error",
          message: "Locker sudah terisi"
        });
    }

    console.error(err);
    return res.status(500).json({
      status: "error",
      message: "SERVER_ERROR"
    });
  }
});

// POST /api/lockers/:id/access
router.post("/:id/access", async (req, res) => {
  const {
    id: lockerId
  } = req.params;
  const {
    code,
    action
  } = req.body;

  if (!code || !action) {
    return res.status(400).json({
      status: "error",
      message: "Data kurang lengkap"
    });
  }
  if (!["continue", "end"].includes(action)) {
    return res.status(400).json({
      status: "error",
      message: "ACTION_INVALID"
    });
  }

  // STEP 1: cek apakah locker sedang terkunci
  const lockStatus = await checkLock(lockerId);
  if (lockStatus.locked) {
    return res.status(429).json({
      status: "error",
      message: "Terlalu banyak percobaan, coba lagi nanti",
    });
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
      if (!verifyCode(code, rental.uniqueCodeHash)) throw new Error("INVALID_CODE");

      const now = new Date();

      if (action === "continue") {
        tx.update(lockerRef, {
          pendingCommand: "unlock",
          unlockedSince: now
        });
        tx.update(rentalRef, {
          lastAccessAt: now,
          accessAction: "continue"
        });
      } else {
        tx.update(lockerRef, {
          pendingCommand: "unlock",
          unlockedSince: now,
          pendingEnd: true,
        });
        tx.update(rentalRef, {
          lastAccessAt: now,
          accessAction: "end",
          status: "pending_end",
        });
      }

      return {
        action,
        unlocked: true
      };
    });

    // STEP 2: kode benar → reset counter
    await resetAttempts(lockerId);
    return res.status(200).json({
      status: "ok",
      ...result
    });
  } catch (err) {
    const code = err.message;

    if (code === "INVALID_CODE") {
      // STEP 3: catat percobaan salah
      const attempt = await recordFailedAttempt(lockerId);
      if (attempt.locked) {
        return res.status(429).json({
          status: "error",
          message: "Terlalu banyak percobaan, locker dikunci sementara",
        });
      }
      return res.status(400).json({
        status: "error",
        message: "Kode tidak valid"
      });
    }

    if (code === "LOCKER_NOT_FOUND" || code === "RENTAL_NOT_FOUND") {
      return res.status(404).json({
        status: "error",
        message: code
      });
    }
    if (code === "LOCKER_NOT_OCCUPIED" || code === "NO_ACTIVE_RENTAL") {
      return res.status(409).json({
        status: "error",
        message: code
      });
    }

    console.error(err);
    return res.status(500).json({
      status: "error",
      message: "SERVER_ERROR"
    });
  }
});

module.exports = router;