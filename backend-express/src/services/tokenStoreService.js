const {
    generateToken
} = require("./qrTokenService");

const TOKEN_VALIDITY_MS = 60 * 1000; // token valid 60 detik
const MAX_TOKEN_HISTORY = 15; // simpan maksimal 15 token terakhir

// In-memory store
// Format: { [lockerId]: { status, frozen, lockerIndex, controllerId, qrTokens: [] } }
const store = {};

function initLocker(lockerId, {
    status,
    frozen,
    lockerIndex,
    controllerId
}) {
    const existing = store[lockerId] || {};

    let newStatus;
    if (status !== undefined && status !== null) {
        newStatus = status;
    } else if (existing.status !== undefined && existing.status !== null) {
        newStatus = existing.status;
    } else {
        newStatus = "empty";
    }

    let newFrozen;
    if (frozen !== undefined && frozen !== null) {
        newFrozen = frozen;
    } else if (existing.frozen !== undefined && existing.frozen !== null) {
        newFrozen = existing.frozen;
    } else {
        newFrozen = false;
    }

    let newLockerIndex;
    if (lockerIndex !== undefined && lockerIndex !== null) {
        newLockerIndex = lockerIndex;
    } else if (existing.lockerIndex !== undefined && existing.lockerIndex !== null) {
        newLockerIndex = existing.lockerIndex;
    } else {
        newLockerIndex = null;
    }

    let newControllerId;
    if (controllerId !== undefined && controllerId !== null) {
        newControllerId = controllerId;
    } else if (existing.controllerId !== undefined && existing.controllerId !== null) {
        newControllerId = existing.controllerId;
    } else {
        newControllerId = null;
    }

    store[lockerId] = {
        status: newStatus,
        frozen: newFrozen,
        lockerIndex: newLockerIndex,
        controllerId: newControllerId,
        qrTokens: existing.qrTokens || [],
    };
}

function setStatus(lockerId, status) {
    if (!store[lockerId]) return;
    store[lockerId].status = status;
}

function setFrozen(lockerId, frozen) {
    if (!store[lockerId]) return;
    store[lockerId].frozen = frozen;
}

function rotate(lockerId) {
    const locker = store[lockerId];
    if (!locker) return false;
    if (locker.status !== "empty") return false;
    if (locker.frozen) return false;

    const now = Date.now();
    const newToken = {
        token: generateToken(),
        generatedAt: now,
        expiresAt: now + TOKEN_VALIDITY_MS,
    };

    const cleaned = locker.qrTokens.filter((t) => t.expiresAt > now);
    cleaned.push(newToken);

    locker.qrTokens =
        cleaned.length > MAX_TOKEN_HISTORY ?
        cleaned.slice(cleaned.length - MAX_TOKEN_HISTORY) :
        cleaned;

    return true;
}

function rotateAll() {
    let count = 0;
    for (const lockerId of Object.keys(store)) {
        if (rotate(lockerId)) count++;
    }
    return count;
}

function getLatestToken(lockerId) {
    const locker = store[lockerId];
    if (!locker) return null;
    const now = Date.now();
    const valid = locker.qrTokens.filter((t) => t.expiresAt > now);
    return valid.length > 0 ? valid[valid.length - 1].token : null;
}

function isTokenValid(lockerId, token) {
    const locker = store[lockerId];
    if (!locker) return false;
    const now = Date.now();
    return locker.qrTokens.some((t) => t.token === token && t.expiresAt > now);
}

function getAll() {
    return store;
}

module.exports = {
    initLocker,
    setStatus,
    setFrozen,
    rotate,
    rotateAll,
    getLatestToken,
    isTokenValid,
    getAll,
};