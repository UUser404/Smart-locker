const { Timestamp } = require("firebase-admin/firestore");

const ONLINE_WINDOW_MS = 15 * 1000;

async function recordControllerHeartbeat(db, controllerId) {
    await db.collection("controllers").doc(controllerId).set({
        lastSeenAt: Timestamp.now(),
    }, { merge: true });
}

async function getControllerStatuses(db, now = Date.now()) {
    const snapshot = await db.collection("controllers").get();

    return snapshot.docs.map((doc) => {
        const data = doc.data();
        const lastSeenAt = data.lastSeenAt;
        const lastSeenMs = lastSeenAt && typeof lastSeenAt.toMillis === "function"
            ? lastSeenAt.toMillis()
            : null;
        const ageMs = lastSeenMs === null ? null : now - lastSeenMs;

        return {
            controller_id: doc.id,
            online: ageMs !== null && ageMs >= 0 && ageMs <= ONLINE_WINDOW_MS,
            last_seen_at: lastSeenMs === null
                ? null
                : new Date(lastSeenMs).toISOString(),
            online_window_seconds: ONLINE_WINDOW_MS / 1000,
        };
    });
}

module.exports = {
    getControllerStatuses,
    recordControllerHeartbeat,
    ONLINE_WINDOW_MS,
};
