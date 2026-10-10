const {
    db
} = require("../firebase");
const tokenStore = require("./tokenStoreService");

// Fallback: daftar locker default kalau Firestore tidak bisa dibaca.
// Ini hanya untuk development ketika quota habis.
const FALLBACK_LOCKERS = [{
        id: "locker_01",
        index: 0
    },
    {
        id: "locker_02",
        index: 1
    },
    {
        id: "locker_03",
        index: 2
    },
    {
        id: "locker_04",
        index: 3
    },
];
const CONTROLLER_ID = "esp32_01";

let retryTimer = null;

async function tryInitFromFirestore() {
    const snapshot = await db.collection("lockers").get();
    let count = 0;

    for (const doc of snapshot.docs) {
        const data = doc.data();
        tokenStore.initLocker(doc.id, {
            status: data.status || "empty",
            frozen: data.qrTokenFrozen || false,
            lockerIndex: data.lockerIndex,
            controllerId: data.controllerId,
        });
        count++;
    }

    return count;
}

function initFallback() {
    for (const l of FALLBACK_LOCKERS) {
        tokenStore.initLocker(l.id, {
            status: "empty",
            frozen: false,
            lockerIndex: l.index,
            controllerId: CONTROLLER_ID,
        });
    }
    console.log(`[tokenStore] Fallback initialized ${FALLBACK_LOCKERS.length} lockers`);
}

async function initTokenStore() {
    try {
        const count = await tryInitFromFirestore();
        console.log(`[tokenStore] Initialized ${count} lockers from Firestore`);
        if (retryTimer) {
            clearInterval(retryTimer);
            retryTimer = null;
        }
    } catch (err) {
        console.error(`[tokenStore] Firestore read failed: ${err.message}`);
        console.log("[tokenStore] Using fallback locker list (dev mode)");

        // Isi fallback hanya kalau store masih kosong
        const existing = tokenStore.getAll();
        if (Object.keys(existing).length === 0) {
            initFallback();
        }

        // Jadwalkan retry kalau belum ada
        if (!retryTimer) {
            console.log("[tokenStore] Will retry in 60s...");
            retryTimer = setInterval(async () => {
                try {
                    const count = await tryInitFromFirestore();
                    console.log(`[tokenStore] Retry success: ${count} lockers from Firestore`);
                    if (retryTimer) {
                        clearInterval(retryTimer);
                        retryTimer = null;
                    }
                } catch (e) {
                    // masih gagal, tetap tunggu
                }
            }, 60 * 1000);
        }
    }
}

module.exports = {
    initTokenStore
};