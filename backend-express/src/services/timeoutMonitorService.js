const {
    Timestamp
} = require("firebase-admin/firestore");
const {
    notifyNeedsAttention
} = require("./fcmService");

const TIMEOUT_MS = 2 * 60 * 1000; // 2 menit

async function checkTimeouts(db) {
    const now = Date.now();

    const snapshot = await db
        .collection("lockers")
        .where("status", "==", "occupied")
        .get();

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