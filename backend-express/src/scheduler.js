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
const TIMEOUT_INTERVAL_MS = 30 * 1000;  // 30 detik — cek transisi occupied → needs_attention
const REMINDER_INTERVAL_MS = 60 * 1000; // 60 detik — reminder ke locker needs_attention

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

    // Reminder: pengingat tiap 1 menit untuk locker yang masih
    // needs_attention. collapseKey sama → accordion di system tray.
    setInterval(async () => {
        try {
            await remindNeedsAttention();
        } catch (err) {
            console.error("[reminder] error:", err.message);
        }
    }, REMINDER_INTERVAL_MS);
}

module.exports = {
    startScheduler
};