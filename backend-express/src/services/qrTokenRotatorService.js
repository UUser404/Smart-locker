const {
    rotateTokens
} = require("./qrTokenService");

async function rotateAllTokens(db) {
    const snapshot = await db
        .collection("lockers")
        .where("status", "==", "empty")
        .get();

    const batch = db.batch();
    let count = 0;

    snapshot.forEach((doc) => {
        const locker = doc.data();
        if (locker.qrTokenFrozen === true) return;

        const newTokens = rotateTokens(locker.qrTokens || []);
        batch.update(doc.ref, {
            qrTokens: newTokens
        });
        count++;
    });

    if (count > 0) {
        await batch.commit();
    }

    return count;
}

module.exports = {
    rotateAllTokens
};