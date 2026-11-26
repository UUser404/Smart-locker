const express = require("express");
const {
    resetCooldown,
    catchUpForDevice,
} = require("../services/fcmService");
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
const {
    getControllerStatuses
} = require("../services/controllerStatusService");
const {
    Timestamp
} = require("firebase-admin/firestore");

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
                status: data.status,
                controller_id: data.controllerId || null,
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
    const auditRef = db.collection("audit_logs").doc();

    try {
        const lockerRef = db.collection("lockers").doc(lockerId);

        const result = await db.runTransaction(async (tx) => {
            const doc = await tx.get(lockerRef);
            if (!doc.exists) throw new Error("LOCKER_NOT_FOUND");

            const locker = doc.data();
            if (locker.status !== "needs_attention") {
                throw new Error("NOT_NEEDS_ATTENTION");
            }

            const resolvedAt = Timestamp.now();
            if (locker.pendingEnd === true && locker.currentRentalId) {
                const rentalRef = db.collection("rentals").doc(locker.currentRentalId);
                const rentalDoc = await tx.get(rentalRef);
                if (!rentalDoc.exists) throw new Error("RENTAL_NOT_FOUND");

                const rental = rentalDoc.data();
                if (rental.status !== "completed") {
                    const endedAt = resolvedAt.toDate();
                    const totalDurationSeconds = Math.floor(
                        (endedAt.getTime() - rental.startedAt.toDate().getTime()) / 1000
                    );

                    tx.update(rentalRef, {
                        status: "completed",
                        endedAt: Timestamp.fromDate(endedAt),
                        totalDurationSeconds,
                    });
                }
            }

            const actor = req.user || {};
            tx.create(auditRef, {
                action: "locker_resolved",
                lockerId,
                rentalId: locker.currentRentalId || null,
                requestedBy: actor.username || null,
                requestedByName: actor.nama || null,
                role: actor.role || null,
                result: "resolved",
                occurredAt: resolvedAt,
            });

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

        resetCooldown(lockerId);

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
        if (err.message === "RENTAL_NOT_FOUND") {
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
// POST /api/admin/lockers/:id/emergency-open
// ============================================================
router.post(
    "/lockers/:id/emergency-open",
    requireAuth,
    requireRole("admin", "petugas"),
    async (req, res) => {
        const { id: lockerId } = req.params;
        const { reason, end_session: endSession } = req.body || {};
        const allowedReasons = [
            "Lupa kode",
            "Pintu macet",
            "Keadaan darurat",
            "Lainnya",
        ];

        if (!allowedReasons.includes(reason) || typeof endSession !== "boolean") {
            return res.status(400).json({
                status: "error",
                message: "EMERGENCY_REQUEST_INVALID",
            });
        }

        const lockerRef = db.collection("lockers").doc(lockerId);
        const auditRef = db.collection("audit_logs").doc();
        const requestedAt = new Date();

        try {
            const result = await db.runTransaction(async (tx) => {
                const lockerDoc = await tx.get(lockerRef);
                if (!lockerDoc.exists) throw new Error("LOCKER_NOT_FOUND");

                const locker = lockerDoc.data();
                if (locker.status !== "occupied") {
                    throw new Error("LOCKER_NOT_OCCUPIED");
                }
                if (!locker.currentRentalId) throw new Error("NO_ACTIVE_RENTAL");
                if (locker.pendingCommand === "unlock" || locker.pendingEnd === true) {
                    throw new Error("EMERGENCY_ACTION_PENDING");
                }

                const rentalRef = db.collection("rentals").doc(locker.currentRentalId);
                const rentalDoc = await tx.get(rentalRef);
                if (!rentalDoc.exists) throw new Error("RENTAL_NOT_FOUND");
                if (rentalDoc.data().status !== "active") {
                    throw new Error("NO_ACTIVE_RENTAL");
                }

                tx.update(rentalRef, {
                    ...(endSession ? { status: "pending_end" } : {}),
                    lastAccessAt: requestedAt,
                    accessAction: endSession
                        ? "emergency_end"
                        : "emergency_continue",
                });

                tx.update(lockerRef, {
                    pendingCommand: "unlock",
                    unlockedSince: requestedAt,
                    pendingEnd: endSession,
                });

                const actor = req.user || {};
                tx.create(auditRef, {
                    action: "emergency_open",
                    lockerId,
                    rentalId: locker.currentRentalId,
                    reason,
                    endSession,
                    requestedBy: actor.username || null,
                    requestedByName: actor.nama || null,
                    role: actor.role || null,
                    result: "queued",
                    occurredAt: Timestamp.fromDate(requestedAt),
                });

                return {
                    locker_id: lockerId,
                    command_status: "queued",
                    end_session: endSession,
                };
            });

            return res.status(202).json({
                status: "ok",
                ...result,
            });
        } catch (err) {
            if (err.message === "LOCKER_NOT_FOUND" || err.message === "RENTAL_NOT_FOUND") {
                return res.status(404).json({
                    status: "error",
                    message: err.message,
                });
            }
            if (
                err.message === "LOCKER_NOT_OCCUPIED" ||
                err.message === "NO_ACTIVE_RENTAL" ||
                err.message === "EMERGENCY_ACTION_PENDING"
            ) {
                return res.status(409).json({
                    status: "error",
                    message: err.message,
                });
            }

            console.error("[emergency-open] error:", err);
            return res.status(500).json({
                status: "error",
                message: "SERVER_ERROR",
            });
        }
    }
);

// ============================================================
// POST /api/admin/register-device — tanpa auth (first-time)
// Setelah register sukses, kirim catch-up notif untuk locker
// needs_attention yang mungkin terlewat.
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

        // Catch-up: kirim notif untuk locker needs_attention yang
        // mungkin terlewat selama device offline / logout.
        // Fire-and-forget — jangan blok response.
        catchUpForDevice(fcm_token).catch((err) => {
            console.error("[catchup] error:", err.message);
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
// POST /api/admin/unregister-device — hapus token saat logout
// (butuh JWT; dipanggil Flutter sebelum session lokal dihapus)
// ============================================================
router.post("/unregister-device", requireAuth, async (req, res) => {
    const {
        fcm_token
    } = req.body;

    if (!fcm_token) {
        return res.status(400).json({
            status: "error",
            message: "fcm_token wajib diisi"
        });
    }

    try {
        await db.collection("petugas_devices").doc(fcm_token).delete();
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
// GET /api/admin/devices/status — admin dan petugas
// ============================================================
router.get(
    "/devices/status",
    requireAuth,
    requireRole("admin", "petugas"),
    async (_req, res) => {
        try {
            const devices = await getControllerStatuses(db);
            return res.status(200).json({ devices });
        } catch (err) {
            console.error("[device-status] error:", err);
            return res.status(500).json({
                status: "error",
                message: "SERVER_ERROR",
            });
        }
    }
);

// ============================================================
// GET /api/admin/audit — admin melihat semua, petugas melihat tindakannya
// ============================================================
router.get(
    "/audit",
    requireAuth,
    requireRole("admin", "petugas"),
    async (req, res) => {
        try {
            const isAdmin = req.user.role === "admin";
            const actorQuery = isAdmin
                ? null
                : req.user.username;
            if (!isAdmin && !actorQuery) {
                return res.status(403).json({
                    status: "error",
                    message: "FORBIDDEN",
                });
            }
            const collections = ["audit_logs", "emergency_actions"];
            const snapshots = await Promise.all(collections.map((name) => {
                const collection = db.collection(name);
                return actorQuery
                    ? collection.where("requestedBy", "==", actorQuery).get()
                    : collection.get();
            }));

            const auditLogs = snapshots.flatMap((snapshot) =>
                snapshot.docs.map((doc) => {
                    const data = doc.data();
                    const occurredAt = data.occurredAt || data.requestedAt || null;
                    const occurredAtDate = occurredAt && typeof occurredAt.toDate === "function"
                        ? occurredAt.toDate()
                        : occurredAt instanceof Date
                            ? occurredAt
                            : null;

                    return {
                        event_id: doc.id,
                        action: data.action || "emergency_open",
                        locker_id: data.lockerId || null,
                        rental_id: data.rentalId || null,
                        actor_username: data.requestedBy || null,
                        actor_name: data.requestedByName || null,
                        actor_role: data.role || null,
                        reason: data.reason || null,
                        end_session: data.endSession ?? null,
                        result: data.result || null,
                        occurred_at: occurredAtDate
                            ? occurredAtDate.toISOString()
                            : null,
                    };
                })
            ).sort((a, b) => {
                const aTime = a.occurred_at ? Date.parse(a.occurred_at) : 0;
                const bTime = b.occurred_at ? Date.parse(b.occurred_at) : 0;
                return bTime - aTime;
            }).slice(0, 100);

            return res.status(200).json({ audit_logs: auditLogs });
        } catch (err) {
            console.error("[audit] error:", err);
            return res.status(500).json({
                status: "error",
                message: "SERVER_ERROR",
            });
        }
    }
);

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

module.exports = router;