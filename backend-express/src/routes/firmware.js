const express = require("express");
const {
    db
} = require("../firebase");
const {
    consumeCommands,
    collectQrTokens
} = require("../services/commandQueueService");
const {
    Timestamp,
    FieldValue
} = require("firebase-admin/firestore");

const router = express.Router();

// GET /api/firmware/:controllerId/poll
router.get("/:controllerId/poll", async (req, res) => {
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
router.post("/:controllerId/report", async (req, res) => {
    const {
        controllerId
    } = req.params;
    const {
        locker_index,
        event
    } = req.body;

    if (locker_index === undefined || !event) {
        return res.status(400).json({
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
            return res.status(404).json({
                status: "error",
                message: "LOCKER_NOT_FOUND"
            });
        }

        const lockerRef = lockerSnap.docs[0].ref;
        const locker = lockerSnap.docs[0].data();

        // Event opened: catat saja (mungkin untuk log nanti)
        if (event === "opened") {
            await lockerRef.update({
                unlockedSince: Timestamp.now(),
            });
            return res.status(200).json({
                status: "ok"
            });
        }

        // Event closed: ini yang penting
        const now = Timestamp.now();

        if (locker.pendingEnd === true && locker.currentRentalId) {
            // Finalisasi sesi
            const rentalRef = db.collection("rentals").doc(locker.currentRentalId);
            const rentalDoc = await rentalRef.get();
            const rental = rentalDoc.data();

            const startedAt = rental.startedAt.toDate();
            const endedAt = new Date();
            const totalDurationSeconds = Math.floor((endedAt.getTime() - startedAt.getTime()) / 1000);

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

            console.log(`[firmware] sesi ${rentalRef.id} selesai, ${totalDurationSeconds}s`);
        } else {
            // Cukup kunci lagi, sesi tetap jalan
            await lockerRef.update({
                unlockedSince: null,
                pendingCommand: null,
            });
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

module.exports = router;