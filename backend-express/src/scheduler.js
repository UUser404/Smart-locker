const {
    db
} = require("./firebase");
const {
    rotateAllTokens
} = require("./services/qrTokenRotatorService");
const {
    checkTimeouts
} = require("./services/timeoutMonitorService");
const {
    remindNeedsAttention
} = require("./services/fcmService");

const ROTATE_INTERVAL_MS = 5 * 1000;    // 5 detik
const TIMEOUT_INTERVAL_MS = 30 * 1000;  // 30 detik
const REMINDER_INTERVAL_MS = 60 * 1000; // 60 detik

function startScheduler() {
    console.log("[scheduler] started");

    setInterval(async () => {
        try {
            await rotateAllTokens(db);
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

    // Reminder: log setiap tick (dengan timestamp) supaya kelihatan
    // scheduler benar-benar jalan di Render, meski tidak ada locker.
    setInterval(async () => {
        const ts = new Date().toISOString();
        try {
            console.log(`[reminder tick] ${ts}`);
            const n = await remindNeedsAttention();
            console.log(`[reminder done] processed=${n}`);
        } catch (err) {
            console.error("[reminder] error:", err.message);
        }
    }, REMINDER_INTERVAL_MS);
}

module.exports = {
    startScheduler
};