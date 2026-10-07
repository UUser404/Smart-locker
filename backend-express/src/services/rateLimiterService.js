const {
    db
} = require("../firebase");
const {
    Timestamp
} = require("firebase-admin/firestore");

const WINDOW_MS = 10 * 60 * 1000; // 10 menit
const MAX_ATTEMPTS = 5;
const LOCK_DURATION_MS = 5 * 60 * 1000; // 5 menit

// Cek apakah locker sedang terkunci karena terlalu banyak salah
async function checkLock(lockerId) {
    const doc = await db.collection("rate_limits").doc(lockerId).get();
    if (!doc.exists) return {
        locked: false
    };

    const data = doc.data();
    if (data.lockedUntil && data.lockedUntil.toMillis() > Date.now()) {
        return {
            locked: true,
            until: data.lockedUntil.toDate().toISOString()
        };
    }
    return {
        locked: false
    };
}

// Catat percobaan salah. Kalau sudah >= 5 dalam 10 menit → lock 5 menit.
async function recordFailedAttempt(lockerId) {
    const ref = db.collection("rate_limits").doc(lockerId);
    const now = Date.now();
    const cutoff = now - WINDOW_MS;

    return db.runTransaction(async (tx) => {
        const doc = await tx.get(ref);
        const data = doc.exists ? doc.data() : {};

        const prev = (data.failedAttempts || [])
            .map((a) => (a.toMillis ? a.toMillis() : a))
            .filter((t) => t > cutoff);

        prev.push(now);

        let lockedUntil = null;
        if (prev.length >= MAX_ATTEMPTS) {
            lockedUntil = Timestamp.fromMillis(now + LOCK_DURATION_MS);
        }

        tx.set(ref, {
            failedAttempts: prev.map((t) => Timestamp.fromMillis(t)),
            lockedUntil,
            updatedAt: Timestamp.now(),
        });

        return {
            attempts: prev.length,
            locked: !!lockedUntil
        };
    });
}

async function resetAttempts(lockerId) {
    await db.collection("rate_limits").doc(lockerId).set({
        failedAttempts: [],
        lockedUntil: null,
        updatedAt: Timestamp.now(),
    });
}

module.exports = {
    checkLock,
    recordFailedAttempt,
    resetAttempts
};