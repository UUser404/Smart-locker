async function configureLockerController(db, env = process.env) {
    const lockerId = env.LOCKER_ID?.trim();
    const controllerId = env.CONTROLLER_ID?.trim() || null;
    const rawLockerIndex = env.LOCKER_INDEX;

    if (!lockerId || lockerId.includes("/")) {
        throw new Error("Set LOCKER_ID to an existing locker document ID");
    }

    const lockerRef = db.collection("lockers").doc(lockerId);
    const locker = await lockerRef.get();
    if (!locker.exists) {
        throw new Error(`Locker ${lockerId} is not registered`);
    }

    if (controllerId === null) {
        await lockerRef.update({
            controllerId: null,
            lockerIndex: null,
        });
        console.log(`${lockerId} is now unassigned from an ESP32`);
        return;
    }

    if (!/^[A-Za-z0-9_-]{1,64}$/.test(controllerId)) {
        throw new Error("CONTROLLER_ID may contain only letters, numbers, _ or -");
    }
    if (rawLockerIndex === undefined || !/^\d+$/.test(rawLockerIndex)) {
        throw new Error("Set LOCKER_INDEX to a non-negative integer");
    }

    const lockerIndex = Number(rawLockerIndex);
    const controller = await db.collection("controllers").doc(controllerId).get();
    if (!controller.exists || !controller.data().authToken) {
        throw new Error(`Controller ${controllerId} is not registered; seed it first`);
    }

    const assignedLockers = await db
        .collection("lockers")
        .where("controllerId", "==", controllerId)
        .get();
    const duplicate = assignedLockers.docs.find((doc) =>
        doc.id !== lockerId && doc.data().lockerIndex === lockerIndex
    );
    if (duplicate) {
        throw new Error(
            `Controller ${controllerId} index ${lockerIndex} is already assigned to ${duplicate.id}`,
        );
    }

    await lockerRef.update({
        controllerId,
        lockerIndex,
    });
    console.log(`${lockerId} is assigned to ${controllerId} index ${lockerIndex}`);
}

if (require.main === module) {
    const {
        db
    } = require("./src/firebase");
    configureLockerController(db)
        .then(() => process.exit(0))
        .catch((err) => {
            console.error("[locker-controller] failed:", err.message);
            process.exit(1);
        });
}

module.exports = {
    configureLockerController,
};
