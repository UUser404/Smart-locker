const {
    db
} = require("./firebase");
const {
    rotateAllTokens
} = require("./services/qrTokenRotatorService");
const {
    checkTimeouts
} = require("./services/timeoutMonitorService");

const ROTATE_INTERVAL_MS = 5 * 1000; // 5 detik
const TIMEOUT_INTERVAL_MS = 30 * 1000; // 30 detik

function startScheduler() {
    console.log("[scheduler] started");

    setInterval(async () => {
        try {
            const n = await rotateAllTokens(db);
            // if (n > 0) console.log(`[rotate] ${n} token dirotasi`);
        } catch (err) {
            console.error("[rotate] error:", err.message);
        }
    }, ROTATE_INTERVAL_MS);

    setInterval(async () => {
        try {
            const n = await checkTimeouts(db);
            if (n > 0) console.log(`[timeout] ${n} locker → needs_attention`);
        } catch (err) {
            console.error("[timeout] error:", err.message);
        }
    }, TIMEOUT_INTERVAL_MS);
}

module.exports = {
    startScheduler
};