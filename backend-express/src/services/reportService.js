const {
    db
} = require("../firebase");

// Mask no HP: "08123456789" → "0812****89"
function maskPhone(phone) {
    if (!phone || phone.length < 6) return phone;
    const start = phone.slice(0, 4);
    const end = phone.slice(-2);
    return `${start}****${end}`;
}

async function getRentalsReport() {
    const snapshot = await db.collection("rentals").orderBy("startedAt", "desc").get();
    const rentals = [];
    const durations = [];
    const lockerCount = {};

    snapshot.forEach((doc) => {
        const data = doc.data();

        const item = {
            rental_id: doc.id,
            locker_id: data.lockerId,
            nama: data.nama,
            no_hp: maskPhone(data.noHp),
            started_at: data.startedAt ? data.startedAt.toDate().toISOString() : null,
            ended_at: data.endedAt ? data.endedAt.toDate().toISOString() : null,
            total_duration_seconds: data.totalDurationSeconds != null ? data.totalDurationSeconds : null,
            status: data.status,
        };
        rentals.push(item);

        // Stats
        if (data.totalDurationSeconds != null) {
            durations.push(data.totalDurationSeconds);
        }
        if (data.lockerId) {
            lockerCount[data.lockerId] = (lockerCount[data.lockerId] || 0) + 1;
        }
    });

    const totalRentals = rentals.length;
    const avgDuration =
        durations.length > 0 ?
        Math.round(durations.reduce((a, b) => a + b, 0) / durations.length) :
        0;

    let busiestLockerId = null;
    let maxCount = 0;
    for (const [lockerId, count] of Object.entries(lockerCount)) {
        if (count > maxCount) {
            maxCount = count;
            busiestLockerId = lockerId;
        }
    }

    return {
        stats: {
            total_rentals: totalRentals,
            avg_duration_seconds: avgDuration,
            busiest_locker_id: busiestLockerId,
        },
        rentals,
    };
}

module.exports = {
    getRentalsReport,
    maskPhone
};