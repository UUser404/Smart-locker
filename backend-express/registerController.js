const crypto = require("crypto");
const {
    db
} = require("./src/firebase");

function generateAuthToken() {
    return crypto.randomBytes(16).toString("hex");
}

async function registerController() {
    const controllerId = process.env.CONTROLLER_ID?.trim();
    if (!controllerId || !/^[A-Za-z0-9_-]{1,64}$/.test(controllerId)) {
        throw new Error("Set CONTROLLER_ID (1-64 characters: letters, numbers, _ or -)");
    }

    const ref = db.collection("controllers").doc(controllerId);
    const existing = await ref.get();
    if (existing.exists && existing.data().authToken) {
        console.log(`Controller ${controllerId} is already registered.`);
        console.log(`Existing authToken: ${existing.data().authToken}`);
        return;
    }

    const authToken = generateAuthToken();
    await ref.set({
        controllerId,
        authToken,
        registeredAt: new Date(),
    }, {
        merge: true,
    });

    console.log(`Controller ${controllerId} registered.`);
    console.log(`One-time device token: ${authToken}`);
    console.log("Store this value as DEVICE_TOKEN in that device's firmware config.");
}

registerController()
    .then(() => process.exit(0))
    .catch((err) => {
        console.error("[controller-register] failed:", err.message);
        process.exit(1);
    });
