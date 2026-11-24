const {
    db: defaultDb
} = require("../firebase");
const tokenStore = require("./tokenStoreService");

// Ambil semua perintah pending dari locker-locker di satu controller
async function consumeCommands(db, controllerId) {
    const snapshot = await db
        .collection("lockers")
        .where("controllerId", "==", controllerId)
        .get();

    const commands = [];
    const batch = db.batch();

    snapshot.forEach((doc) => {
        const locker = doc.data();
        if (locker.pendingCommand === "unlock") {
            commands.push({
                locker_index: locker.lockerIndex,
                action: "unlock",
                pulse_hold: true,
            });
            batch.update(doc.ref, {
                pendingCommand: null
            });
        }
    });

    if (commands.length > 0) {
        await batch.commit();
    }

    return commands;
}

// Kumpulkan token QR untuk semua locker di satu controller
async function collectQrTokens(db, controllerId) {
    const tokens = {};
    const all = tokenStore.getAll();
    const WEB_BASE_URL = "https://www.locker-qu.com";

    for (const [lockerId, locker] of Object.entries(all)) {
        if (locker.controllerId === controllerId) {
            const latestToken = tokenStore.getLatestToken(lockerId);

            if (latestToken) {
                // 🔥 PERUBAHAN: Rakit URL utuh
                const fullUrl = `${WEB_BASE_URL}/${lockerId}?token=${latestToken}`;
                tokens[String(locker.lockerIndex)] = fullUrl;
            } else {
                tokens[String(locker.lockerIndex)] = null;
            }
        }
    }

    return tokens;
}

// Cukup satu module.exports
module.exports = {
    consumeCommands,
    collectQrTokens,
};