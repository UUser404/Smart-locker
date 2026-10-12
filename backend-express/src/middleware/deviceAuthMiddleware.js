const {
    db
} = require("../firebase");

// Cache authToken di memory biar tidak read Firestore tiap request
const tokenCache = {};
const CACHE_TTL_MS = 5 * 60 * 1000; // 5 menit
let cacheTime = 0;

async function loadToken(controllerId) {
    const now = Date.now();
    if (tokenCache[controllerId] && now - cacheTime < CACHE_TTL_MS) {
        return tokenCache[controllerId];
    }

    const doc = await db.collection("controllers").doc(controllerId).get();
    if (!doc.exists) return null;

    const data = doc.data();
    tokenCache[controllerId] = data.authToken;
    cacheTime = now;
    return data.authToken;
}

async function requireDeviceAuth(req, res, next) {
    const {
        controllerId
    } = req.params;
    const headerToken = req.headers["x-device-token"];

    if (!controllerId) {
        return res.status(400).json({
            status: "error",
            message: "MISSING_CONTROLLER_ID",
        });
    }

    if (!headerToken) {
        return res.status(401).json({
            status: "error",
            message: "MISSING_DEVICE_TOKEN",
        });
    }

    try {
        const storedToken = await loadToken(controllerId);

        if (!storedToken) {
            return res.status(404).json({
                status: "error",
                message: "CONTROLLER_NOT_REGISTERED",
            });
        }

        if (headerToken !== storedToken) {
            return res.status(401).json({
                status: "error",
                message: "INVALID_DEVICE_TOKEN",
            });
        }

        req.controllerId = controllerId;
        next();
    } catch (err) {
        console.error("[deviceAuth] error:", err.message);
        return res.status(500).json({
            status: "error",
            message: "SERVER_ERROR",
        });
    }
}

// Buat clear cache (dipakai saat register token baru)
function clearTokenCache() {
    for (const k of Object.keys(tokenCache)) delete tokenCache[k];
    cacheTime = 0;
}

module.exports = {
    requireDeviceAuth,
    clearTokenCache
};