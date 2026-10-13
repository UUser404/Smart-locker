const {
    Timestamp
} = require("firebase-admin/firestore");
const {
    notifyNeedsAttention
} = require("./fcmService");

const TIMEOUT_MS = 2 * 60 * 1000;
let lastQuotaErrorLog = 0;
const QUOTA_LOG_INTERVAL_MS = 5 * 60 * 1000; // log tiap 5 menit kalau quota habis

async function checkTimeouts(db) {
    const now = Date.now();

    let snapshot;
    try {
        snapshot = await db
            .collection("lockers")
            .where("status", "==", "occupied")
            .get();
    } catch (err) {
        // Kalau quota habis, jangan spam log
        if (err.code === 8 || (err.message && err.message.includes("Quota exceeded"))) {
            const nowMs = Date.now();
            if (nowMs - lastQuotaErrorLog > QUOTA_LOG_INTERVAL_MS) {
                console.log("[timeout] quota habis, skip sampai reset");
                lastQuotaErrorLog = nowMs;
            }
            return 0;
        }
        throw err; // error lain, biarkan scheduler log
    }

    const batch = db.batch();
    const triggered = [];

    snapshot.forEach((doc) => {
        const locker = doc.data();
        if (!locker.unlockedSince) return;

        const unlockedMs = locker.unlockedSince.toMillis();
        if (now - unlockedMs > TIMEOUT_MS) {
            batch.update(doc.ref, {
                status: "needs_attention",
                needsAttentionSince: Timestamp.now(),
            });
            triggered.push(doc.id);
        }
    });

    if (triggered.length > 0) {
        await batch.commit();
        for (const lockerId of triggered) {
            console.log(`[timeout] ${lockerId} → needs_attention`);
            await notifyNeedsAttention(lockerId);
        }
    }

    return triggered.length;
}

module.exports = {
    checkTimeouts,
    TIMEOUT_MS
};