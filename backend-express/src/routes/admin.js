const express = require("express");
const {
    db
} = require("../firebase");
const {
    requireAuth,
    requireRole
} = require("../middleware/authMiddleware");
const {
    getRentalsReport
} = require("../services/reportService");
const tokenStore = require("../services/tokenStoreService");

const router = express.Router();

// ============================================================
// GET /api/admin/lockers — list semua locker
// ============================================================
router.get("/lockers", requireAuth, async (req, res) => {
    try {
        const snapshot = await db.collection("lockers").get();
        const now = Date.now();
        const lockers = [];

        for (const doc of snapshot.docs) {
            const data = doc.data();
            const item = {
                locker_id: doc.id,
                status: data.status
            };

            if (data.status === "occupied" && data.currentRentalId) {
                const rentalDoc = await db
                    .collection("rentals")
                    .doc(data.currentRentalId)
                    .get();

                if (rentalDoc.exists) {
                    const rental = rentalDoc.data();
                    if (rental.startedAt) {
                        item.elapsed_seconds = Math.floor(
                            (now - rental.startedAt.toMillis()) / 1000
                        );
                    }
                }
            }

            if (data.status === "needs_attention" && data.needsAttentionSince) {
                item.unlocked_since = data.needsAttentionSince.toDate().toISOString();
            }

            lockers.push(item);
        }

        return res.status(200).json({
            lockers
        });
    } catch (err) {
        console.error(err);
        return res.status(500).json({
            status: "error",
            message: "SERVER_ERROR"
        });
    }
});

// ============================================================
// POST /api/admin/lockers/:id/resolve
// ============================================================
router.post("/lockers/:id/resolve", requireAuth, async (req, res) => {
    const {
        id: lockerId
    } = req.params;

    try {
        const lockerRef = db.collection("lockers").doc(lockerId);

        const result = await db.runTransaction(async (tx) => {
            const doc = await tx.get(lockerRef);
            if (!doc.exists) throw new Error("LOCKER_NOT_FOUND");

            const locker = doc.data();
            if (locker.status !== "needs_attention") {
                throw new Error("NOT_NEEDS_ATTENTION");
            }

            tx.update(lockerRef, {
                status: "empty",
                currentRentalId: null,
                qrTokenFrozen: false,
                unlockedSince: null,
                pendingCommand: null,
                pendingEnd: false,
                needsAttentionSince: null,
            });

            return {
                locker_id: lockerId,
                new_status: "empty"
            };
        });

        // Update in-memory token store
        tokenStore.setStatus(lockerId, "empty");
        tokenStore.setFrozen(lockerId, false);

        return res.status(200).json({
            status: "ok",
            ...result
        });
    } catch (err) {
        if (err.message === "LOCKER_NOT_FOUND") {
            return res.status(404).json({
                status: "error",
                message: err.message
            });
        }
        if (err.message === "NOT_NEEDS_ATTENTION") {
            return res.status(409).json({
                status: "error",
                message: err.message
            });
        }
        console.error(err);
        return res.status(500).json({
            status: "error",
            message: "SERVER_ERROR"
        });
    }
});

// ============================================================
// POST /api/admin/register-device — tanpa auth (first-time)
// ============================================================
router.post("/register-device", async (req, res) => {
    const {
        fcm_token,
        petugas_id
    } = req.body;

    if (!fcm_token || !petugas_id) {
        return res
            .status(400)
            .json({
                status: "error",
                message: "Data kurang lengkap"
            });
    }

    try {
        await db.collection("petugas_devices").doc(fcm_token).set({
            fcmToken: fcm_token,
            petugasId: petugas_id,
            registeredAt: new Date(),
        });

        return res.status(200).json({
            status: "ok"
        });
    } catch (err) {
        console.error(err);
        return res.status(500).json({
            status: "error",
            message: "SERVER_ERROR"
        });
    }
});

// ============================================================
// GET /api/admin/reports/rentals — hanya admin
// ============================================================
router.get(
    "/reports/rentals",
    requireAuth,
    requireRole("admin"),
    async (req, res) => {
        try {
            const result = await getRentalsReport();
            return res.status(200).json(result);
        } catch (err) {
            console.error(err);
            return res.status(500).json({
                status: "error",
                message: "SERVER_ERROR"
            });
        }
    }
);

// ============================================================
// GET /api/admin/debug/tokens — DEV ONLY (hapus sebelum production)
// ============================================================
router.get(
    "/debug/tokens",
    requireAuth,
    requireRole("admin"),
    async (req, res) => {
        const all = tokenStore.getAll();
        const result = {};

        for (const [lockerId, locker] of Object.entries(all)) {
            result[lockerId] = {
                status: locker.status,
                frozen: locker.frozen,
                lockerIndex: locker.lockerIndex,
                controllerId: locker.controllerId,
                latestToken: tokenStore.getLatestToken(lockerId),
            };
        }

        return res.status(200).json(result);
    }
);

module.exports = router;