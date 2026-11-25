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
    const configuredBaseUrl = process.env.WEB_BASE_URL;
    if (!configuredBaseUrl || !configuredBaseUrl.trim()) {
        throw new Error("WEB_BASE_URL environment variable is required");
    }

    let webBaseUrl;
    try {
        const parsedBaseUrl = new URL(configuredBaseUrl);
        if (!["http:", "https:"].includes(parsedBaseUrl.protocol) ||
            parsedBaseUrl.search || parsedBaseUrl.hash || parsedBaseUrl.username ||
            parsedBaseUrl.password) {
            throw new Error();
        }
        webBaseUrl = parsedBaseUrl.toString().replace(/\/+$/, "");
    } catch (err) {
        throw new Error("WEB_BASE_URL must be an absolute HTTP(S) URL without query or fragment");
    }

    for (const [lockerId, locker] of Object.entries(all)) {
        if (locker.controllerId === controllerId) {
            const latestToken = tokenStore.getLatestToken(lockerId);

            if (latestToken) {
                const fullUrl =
                    `${webBaseUrl}/${encodeURIComponent(lockerId)}?token=${encodeURIComponent(latestToken)}`;
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