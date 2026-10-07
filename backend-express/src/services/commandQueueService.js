// Ambil semua perintah pending dari locker-locker di satu controller
// Sekaligus "consume" (clear) supaya tidak dieksekusi 2x
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
    const snapshot = await db
        .collection("lockers")
        .where("controllerId", "==", controllerId)
        .get();

    const now = Date.now();
    const tokens = {};

    snapshot.forEach((doc) => {
        const locker = doc.data();
        const qrTokens = locker.qrTokens || [];
        // Ambil token paling baru yang masih valid
        const validTokens = qrTokens.filter((t) => t.expiresAt > now);
        const latest = validTokens.length > 0 ? validTokens[validTokens.length - 1] : null;

        tokens[String(locker.lockerIndex)] = latest ? latest.token : null;
    });

    return tokens;
}

module.exports = {
    consumeCommands,
    collectQrTokens
};