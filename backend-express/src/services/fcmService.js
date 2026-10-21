const {
    getMessaging
} = require("firebase-admin/messaging");
const {
    db
} = require("../firebase");

// ============================================================
// Anti alarm fatigue
// ============================================================
// Simpan timestamp notif terakhir per locker (in-memory)
const lastNotifiedAt = {};
const NOTIF_COOLDOWN_MS = 10 * 60 * 1000; // 10 menit jeda

// ============================================================
// Kirim notifikasi ke semua device petugas terdaftar
// ============================================================
async function notifyNeedsAttention(lockerId) {
    // 1. Cek jeda — kalau baru kirim < 10 menit, skip
    const now = Date.now();
    const last = lastNotifiedAt[lockerId] || 0;
    if (now - last < NOTIF_COOLDOWN_MS) {
        const sisaDetik = Math.floor((NOTIF_COOLDOWN_MS - (now - last)) / 1000);
        console.log(`[fcm] ${lockerId}: skip (cooldown, ${sisaDetik}s lagi)`);
        return;
    }

    try {
        // 2. Ambil semua FCM token petugas
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

        // 3. Hitung durasi terbuka untuk body notif
        const lockerDoc = await db.collection("lockers").doc(lockerId).get();
        let durasiText = "baru saja";
        if (lockerDoc.exists) {
            const data = lockerDoc.data();
            if (data.needsAttentionSince) {
                const elapsedMs = Date.now() - data.needsAttentionSince.toMillis();
                const elapsedMin = Math.floor(elapsedMs / 60000);
                durasiText = `${elapsedMin} menit lalu`;
            }
        }

        // 4. Kirim via FCM
        const messaging = getMessaging();
        const response = await messaging.sendEachForMulticast({
            tokens,
            // Notification message — tampil otomatis walau app tertutup
            notification: {
                title: "⚠️ Locker Perlu Perhatian",
                body: `Locker ${lockerId.toUpperCase()} — pintu terbuka sejak ${durasiText}. Segera cek.`,
            },
            // Data message — untuk deep-link ke detail locker
            data: {
                type: "needs_attention",
                locker_id: lockerId,
                click_action: "FLUTTER_NOTIFICATION_CLICK",
            },
            // Anti alarm fatigue
            android: {
                priority: "high",
                collapseKey: `locker_${lockerId}`,
                ttl: 30 * 60 * 1000, // 30 menit
                notification: {
                    channelId: "smart_locker_alert",
                    priority: "high",
                    defaultSound: true,
                    defaultVibrateTimings: true,
                },
            },
            apns: {
                headers: {
                    "apns-priority": "10",
                    "apns-collapse-id": `locker_${lockerId}`,
                },
                payload: {
                    aps: {
                        sound: "default",
                        badge: 1,
                    },
                },
            },
        });

        // 5. Cleanup token yang sudah tidak valid.
        // Menangkap kasus: device uninstall, logout paksa, token dihapus
        // via deleteToken() (mis. unregister backend gagal karena JWT
        // expired). Ini yang bikin token yatim di petugas_devices hilang
        // otomatis pada notif berikutnya.
        const invalidTokens = [];
        response.responses.forEach((resp, idx) => {
            if (!resp.success) {
                const code = resp.error?.code;
                if (
                    code === "messaging/registration-token-not-registered" ||
                    code === "messaging/invalid-registration-token"
                ) {
                    invalidTokens.push(tokens[idx]);
                }
            }
        });

        if (invalidTokens.length > 0) {
            console.log(
                `[fcm] membersihkan ${invalidTokens.length} token invalid dari petugas_devices`
            );
            const batch = db.batch();
            invalidTokens.forEach((t) => {
                batch.delete(db.collection("petugas_devices").doc(t));
            });
            await batch.commit();
        }

        console.log(
            `[fcm] ${lockerId}: sent=${response.successCount}, failed=${response.failureCount}`
        );

        // 6. Update timestamp setelah kirim
        lastNotifiedAt[lockerId] = now;
    } catch (err) {
        console.error("[fcm] error:", err.message);
    }
}

// ============================================================
// Reset cooldown saat locker di-resolve
// (dipanggil dari endpoint /admin/lockers/:id/resolve)
// ============================================================
function resetCooldown(lockerId) {
    delete lastNotifiedAt[lockerId];
    console.log(`[fcm] ${lockerId}: cooldown di-reset`);
}

module.exports = {
    notifyNeedsAttention,
    resetCooldown
};