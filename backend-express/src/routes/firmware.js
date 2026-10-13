const express = require("express");
const lockerStateStore = require("../services/lockerStateStore");
const {
    requireDeviceAuth
} = require("../middleware/deviceAuthMiddleware");
const {
    db
} = require("../firebase");
const {
    consumeCommands,
    collectQrTokens,
} = require("../services/commandQueueService");
const tokenStore = require("../services/tokenStoreService");
const {
    Timestamp
} = require("firebase-admin/firestore");

const router = express.Router();

// GET /api/firmware/:controllerId/poll
router.get("/:controllerId/poll", requireDeviceAuth, async (req, res) => {
    const {
        controllerId
    } = req.params;

    try {
        const commands = await consumeCommands(db, controllerId);
        const qr_tokens = await collectQrTokens(db, controllerId);

        return res.status(200).json({
            commands,
            qr_tokens
        });
    } catch (err) {
        console.error(err);
        return res.status(500).json({
            status: "error",
            message: "SERVER_ERROR"
        });
    }
});

// POST /api/firmware/:controllerId/report
router.post("/:controllerId/report", requireDeviceAuth, async (req, res) => {
    const {
        controllerId
    } = req.params;
    const {
        locker_index,
        event
    } = req.body;

    if (locker_index === undefined || !event) {
        return res
            .status(400)
            .json({
                status: "error",
                message: "Data kurang lengkap"
            });
    }
    if (!["opened", "closed"].includes(event)) {
        return res.status(400).json({
            status: "error",
            message: "EVENT_INVALID"
        });
    }

    try {
        const lockerSnap = await db
            .collection("lockers")
            .where("controllerId", "==", controllerId)
            .where("lockerIndex", "==", locker_index)
            .limit(1)
            .get();

        if (lockerSnap.empty) {
            return res
                .status(404)
                .json({
                    status: "error",
                    message: "LOCKER_NOT_FOUND"
                });
        }

        const lockerRef = lockerSnap.docs[0].ref;
        const lockerId = lockerSnap.docs[0].id;
        const locker = lockerSnap.docs[0].data();

        // Event opened: cukup catat timestamp
        if (event === "opened") {
            await lockerRef.update({
                unlockedSince: Timestamp.now()
            });
            return res.status(200).json({
                status: "ok"
            });
        }

        // Event closed: finalisasi atau re-lock
        if (locker.pendingEnd === true && locker.currentRentalId) {
            // Finalisasi sesi
            const rentalRef = db.collection("rentals").doc(locker.currentRentalId);
            const rentalDoc = await rentalRef.get();
            const rental = rentalDoc.data();

            const startedAt = rental.startedAt.toDate();
            const endedAt = new Date();
            const totalDurationSeconds = Math.floor(
                (endedAt.getTime() - startedAt.getTime()) / 1000
            );

            await rentalRef.update({
                status: "completed",
                endedAt: Timestamp.fromDate(endedAt),
                totalDurationSeconds,
            });

            await lockerRef.update({
                status: "empty",
                currentRentalId: null,
                qrTokenFrozen: false,
                unlockedSince: null,
                pendingCommand: null,
                pendingEnd: false,
            });

            // === Update in-memory token store ===
            tokenStore.setStatus(lockerId, "empty");
            tokenStore.setFrozen(lockerId, false);

            console.log(
                `[firmware] sesi ${rentalRef.id} selesai, ${totalDurationSeconds}s`
            );
        } else {
            // Cukup kunci lagi, sesi tetap jalan
            await lockerRef.update({
                unlockedSince: null,
                pendingCommand: null,
            });
            // Status locker tetap occupied, tidak ada perubahan token store
        }

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
// POST /api/firmware/:controllerId/sync
// Gabungan /poll + /report dalam 1 request
// Request body: { lockers: [{ index, door_open, solenoid_on }, ...] }
// ============================================================
router.post("/:controllerId/sync", requireDeviceAuth, async (req, res) => {
    const {
        controllerId
    } = req.params;
    const {
        lockers
    } = req.body;

    if (!Array.isArray(lockers)) {
        return res.status(400).json({
            status: "error",
            message: "lockers array wajib"
        });
    }

    try {
        // Ambil semua locker yang terdaftar untuk controller ini
        const snapshot = await db
            .collection("lockers")
            .where("controllerId", "==", controllerId)
            .get();

        const byIndex = {};
        snapshot.forEach((doc) => {
            const data = doc.data();
            byIndex[data.lockerIndex] = {
                docId: doc.id,
                data
            };
        });

        // Proses setiap locker dari request
        for (const item of lockers) {
            const idx = item.index;
            if (idx === undefined || !byIndex[idx]) continue;

            const {
                docId,
                data: locker
            } = byIndex[idx];
            const prevState = lockerStateStore.get(docId);
            const nowOpen = !!item.door_open;

            // Deteksi transisi
            if (prevState.doorOpen !== nowOpen) {
                if (nowOpen) {
                    console.log(`[sync] ${docId}: pintu terbuka`);
                } else {
                    console.log(`[sync] ${docId}: pintu tertutup`);
                    // Jalankan logic "closed" (sama seperti /report)
                    await handleDoorClosed(docId, locker);
                }
                lockerStateStore.update(docId, {
                    doorOpen: nowOpen,
                    solenoidOn: !!item.solenoid_on,
                });
            } else {
                // State tidak berubah, tetap update solenoid
                lockerStateStore.update(docId, {
                    doorOpen: nowOpen,
                    solenoidOn: !!item.solenoid_on,
                });
            }
        }

        // Ambil commands + qr_tokens (sama seperti /poll)
        const commands = await consumeCommands(db, controllerId);
        const qr_tokens = await collectQrTokens(db, controllerId);

        return res.status(200).json({
            commands,
            qr_tokens
        });
    } catch (err) {
        console.error("[sync] error:", err);
        return res.status(500).json({
            status: "error",
            message: "SERVER_ERROR"
        });
    }
});

// Helper: proses event door closed
async function handleDoorClosed(lockerId, locker) {
    const lockerRef = db.collection("lockers").doc(lockerId);
    const now = Timestamp.now();

    if (locker.pendingEnd === true && locker.currentRentalId) {
        // Finalisasi sesi
        const rentalRef = db.collection("rentals").doc(locker.currentRentalId);
        const rentalDoc = await rentalRef.get();

        if (rentalDoc.exists) {
            const rental = rentalDoc.data();
            const startedAt = rental.startedAt.toDate();
            const endedAt = new Date();
            const durationSec = Math.floor((endedAt.getTime() - startedAt.getTime()) / 1000);

            await rentalRef.update({
                status: "completed",
                endedAt: Timestamp.fromDate(endedAt),
                totalDurationSeconds: durationSec,
            });

            console.log(`[sync] sesi ${rentalRef.id} selesai, ${durationSec}s`);
        }

        await lockerRef.update({
            status: "empty",
            currentRentalId: null,
            qrTokenFrozen: false,
            unlockedSince: null,
            pendingCommand: null,
            pendingEnd: false,
        });

        // Update tokenStore
        const tokenStore = require("../services/tokenStoreService");
        tokenStore.setStatus(lockerId, "empty");
        tokenStore.setFrozen(lockerId, false);
    } else {
        // Cukup kunci lagi
        await lockerRef.update({
            unlockedSince: null,
            pendingCommand: null,
        });
    }
}

module.exports = router;