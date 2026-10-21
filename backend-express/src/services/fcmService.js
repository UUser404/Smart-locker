const {
    getMessaging
} = require("firebase-admin/messaging");
const {
    db
} = require("../firebase");

// ============================================================
// State in-memory
// ============================================================
// Simpan timestamp notif terakhir per locker — dipakai untuk
// throttle reminder (jangan kirim ulang < 60 detik)
const lastNotifiedAt = {};
const REMINDER_INTERVAL_MS = 60 * 1000; // 1 menit

// ============================================================
// Helper: ambil durasi terbuka (menit) dari Firestore
// ============================================================
function computeElapsedMinutes(lockerData) {
    if (!lockerData || !lockerData.needsAttentionSince) return 0;
    const elapsedMs = Date.now() - lockerData.needsAttentionSince.toMillis();
    return Math.floor(elapsedMs / 60000);
}

// ============================================================
// Helper: cek locker masih needs_attention?
// ============================================================
async function isStillNeedsAttention(lockerId) {
    const doc = await db.collection("lockers").doc(lockerId).get();
    if (!doc.exists) return null;
    const data = doc.data();
    if (data.status !== "needs_attention") return null;
    return data;
}

// ============================================================
// Kirim notifikasi ke semua device petugas
// mode: "initial" | "reminder"
//  - initial : notif pertama saat locker baru jadi needs_attention,
//              pakai channel high priority + sound + vibrate
//  - reminder: pengingat tiap 1 menit, channel low priority
//              (tidak bunyi tiap menit, tapi tetap muncul & update
//              body). collapseKey sama → accordion di tray.
// ============================================================
async function notifyNeedsAttention(lockerId, mode = "initial") {
    // 1. Cek locker masih needs_attention? Kalau tidak, skip.
    const lockerData = await isStillNeedsAttention(lockerId);
    if (!lockerData) {
        console.log(`[fcm] ${lockerId}: skip (status bukan needs_attention)`);
        return;
    }

    // 2. Throttle reminder — jangan kirim ulang < 60 detik
    const now = Date.now();
    const last = lastNotifiedAt[lockerId] || 0;
    if (now - last < REMINDER_INTERVAL_MS) {
        const sisaDetik = Math.floor((REMINDER_INTERVAL_MS - (now - last)) / 1000);
        console.log(`[fcm] ${lockerId}: skip (throttle, ${sisaDetik}s lagi)`);
        return;
    }

    try {
        // 3. Ambil semua FCM token petugas
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

        // 4. Body notif adaptif
        const elapsedMin = computeElapsedMinutes(lockerData);
        const isReminder = mode === "reminder";
        const title = isReminder
            ? "⚠️ Masih Perlu Perhatian"
            : "⚠️ Locker Perlu Perhatian";
        const body = isReminder
            ? `Locker ${lockerId.toUpperCase()} — masih terbuka, ${elapsedMin} menit. Segera cek.`
            : `Locker ${lockerId.toUpperCase()} — pintu terbuka sejak ${elapsedMin} menit lalu. Segera cek.`;

        // 5. Kirim via FCM
        const messaging = getMessaging();
        const channelId = isReminder
            ? "smart_locker_reminder"  // low importance, silent
            : "smart_locker_alert";    // high importance, sound

        const response = await messaging.sendEachForMulticast({
            tokens,
            notification: { title, body },
            data: {
                type: "needs_attention",
                locker_id: lockerId,
                mode,
                click_action: "FLUTTER_NOTIFICATION_CLICK",
            },
            android: {
                priority: isReminder ? "normal" : "high",
                collapseKey: `locker_${lockerId}`, // accordion: 1 locker = 1 slot
                ttl: 60 * 60 * 1000, // 1 jam
                notification: {
                    channelId,
                    priority: isReminder ? "default" : "high",
                    // Reminder: no sound/vibrate, tapi tetap update body
                    defaultSound: !isReminder,
                    defaultVibrateTimings: !isReminder,
                    // Biar reminder tidak bunyi ulang kalau masih di tray
                    // (accordion: body update, tapi tidak re-alert)
                    ...(isReminder ? { setOnlyAlertOnce: true } : {}),
                },
            },
            apns: {
                headers: {
                    "apns-priority": isReminder ? "5" : "10",
                    // collapse-id sama → notif baru replace notif lama
                    "apns-collapse-id": `locker_${lockerId}`,
                },
                payload: {
                    aps: {
                        sound: isReminder ? undefined : "default",
                        badge: 1,
                        "interruption-level": isReminder ? "passive" : "active",
                    },
                },
            },
        });

        // 6. Cleanup token invalid
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
            `[fcm] ${lockerId} (${mode}): sent=${response.successCount}, failed=${response.failureCount}`
        );

        // 7. Update timestamp
        lastNotifiedAt[lockerId] = now;
    } catch (err) {
        console.error("[fcm] error:", err.message);
    }
}

// ============================================================
// Reminder loop — dipanggil scheduler tiap 1 menit.
// Cari semua locker needs_attention, kirim reminder.
// Log verbose supaya mudah debug saat reminder tidak jalan.
// ============================================================
async function remindNeedsAttention() {
    let snapshot;
    try {
        snapshot = await db
            .collection("lockers")
            .where("status", "==", "needs_attention")
            .get();
    } catch (err) {
        console.error("[fcm reminder] error query:", err.message);
        return 0;
    }

    const lockers = snapshot.docs.map((d) => d.id);
    console.log(
        `[fcm reminder] query found ${lockers.length} locker(s): ${lockers.join(", ") || "-"}`
    );

    if (lockers.length === 0) return 0;

    let sent = 0;
    for (const lockerId of lockers) {
        // Cek throttle sebelum panggil notifyNeedsAttention
        const last = lastNotifiedAt[lockerId] || 0;
        const sisaMs = REMINDER_INTERVAL_MS - (Date.now() - last);
        if (sisaMs > 0) {
            console.log(
                `[fcm reminder] ${lockerId}: skip throttle (${Math.ceil(sisaMs / 1000)}s)`
            );
            continue;
        }

        await notifyNeedsAttention(lockerId, "reminder");
        sent++;
    }
    return sent;
}

// ============================================================
// Catch-up: kirim notif ke device tertentu saja (saat login).
// Device yang baru login dapat notif untuk locker needs_attention
// yang belum dia lihat.
// ============================================================
async function sendCatchUpToToken(token, lockerId) {
    const lockerData = await isStillNeedsAttention(lockerId);
    if (!lockerData) return false;

    const elapsedMin = computeElapsedMinutes(lockerData);
    const messaging = getMessaging();

    try {
        await messaging.send({
            token,
            notification: {
                title: "⚠️ Locker Perlu Perhatian",
                body: `Locker ${lockerId.toUpperCase()} — pintu terbuka sejak ${elapsedMin} menit lalu. Segera cek.`,
            },
            data: {
                type: "needs_attention",
                locker_id: lockerId,
                mode: "catchup",
                click_action: "FLUTTER_NOTIFICATION_CLICK",
            },
            android: {
                priority: "high",
                collapseKey: `locker_${lockerId}`,
                ttl: 60 * 60 * 1000,
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
                    aps: { sound: "default", badge: 1 },
                },
            },
        });
        return true;
    } catch (err) {
        const code = err.code;
        if (
            code === "messaging/registration-token-not-registered" ||
            code === "messaging/invalid-registration-token"
        ) {
            // Token invalid — hapus dari Firestore
            try {
                await db.collection("petugas_devices").doc(token).delete();
            } catch (_) {}
        }
        return false;
    }
}

// ============================================================
// Catch-up untuk 1 device: kirim notif semua locker
// needs_attention ke token device yang baru login.
// ============================================================
async function catchUpForDevice(fcmToken) {
    let snapshot;
    try {
        snapshot = await db
            .collection("lockers")
            .where("status", "==", "needs_attention")
            .get();
    } catch (err) {
        console.error("[fcm catchup] error query:", err.message);
        return 0;
    }

    if (snapshot.empty) {
        console.log("[fcm catchup] tidak ada locker needs_attention");
        return 0;
    }

    let sent = 0;
    for (const doc of snapshot.docs) {
        const ok = await sendCatchUpToToken(fcmToken, doc.id);
        if (ok) sent++;
    }
    console.log(
        `[fcm catchup] ${sent} notif terkirim ke token ${fcmToken.slice(0, 12)}...`
    );
    return sent;
}

// ============================================================
// Reset state saat locker di-resolve
// ============================================================
function resetCooldown(lockerId) {
    delete lastNotifiedAt[lockerId];
    console.log(`[fcm] ${lockerId}: state notif di-reset`);
}

module.exports = {
    notifyNeedsAttention,
    remindNeedsAttention,
    catchUpForDevice,
    resetCooldown,
};