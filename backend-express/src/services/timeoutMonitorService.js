const {
    Timestamp
} = require("firebase-admin/firestore");

const TIMEOUT_MS = 2 * 60 * 1000; // 2 menit

async function checkTimeouts(db) {
    const now = Date.now();

    const snapshot = await db
        .collection("lockers")
        .where("status", "==", "occupied")
        .get();

    const batch = db.batch();
    let count = 0;

    snapshot.forEach((doc) => {
        const locker = doc.data();
        if (!locker.unlockedSince) return;

        const unlockedMs = locker.unlockedSince.toMillis();
        if (now - unlockedMs > TIMEOUT_MS) {
            batch.update(doc.ref, {
                status: "needs_attention",
                needsAttentionSince: Timestamp.now(),
            });
            count++;
            console.log(`[timeout] ${doc.id} → needs_attention`);
        }
    });

    if (count > 0) {
        await batch.commit();
    }

    return count;
}

module.exports = {
    checkTimeouts,
    TIMEOUT_MS
};