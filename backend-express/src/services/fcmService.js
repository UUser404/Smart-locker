const {
    getMessaging
} = require("firebase-admin/messaging");
const {
    db
} = require("../firebase");

async function notifyNeedsAttention(lockerId) {
    try {
        const snapshot = await db.collection("petugas_devices").get();
        const tokens = [];
        snapshot.forEach((doc) => {
            const data = doc.data();
            if (data.fcmToken) tokens.push(data.fcmToken);
        });

        if (tokens.length === 0) {
            console.log("[fcm] tidak ada device terdaftar, skip");
            return;
        }

        const messaging = getMessaging();
        const response = await messaging.sendEachForMulticast({
            tokens,
            notification: {
                title: "Locker Perlu Perhatian",
                body: `Locker ${lockerId} - pintu belum tertutup sejak 2 menit lalu`,
            },
            data: {
                locker_id: lockerId
            },
        });

        console.log(
            `[fcm] ${lockerId}: sent=${response.successCount}, failed=${response.failureCount}`
        );
    } catch (err) {
        console.error("[fcm] error:", err.message);
    }
}

module.exports = {
    notifyNeedsAttention
};