const {
    db
} = require("./src/firebase");
const {
    hashPassword
} = require("./src/services/authService");

async function seedPetugas() {
    const users = [{
            username: "admin",
            password: "admin123",
            role: "admin",
            nama: "Admin Smart Locker"
        },
        {
            username: "petugas1",
            password: "petugas123",
            role: "petugas",
            nama: "Budi Santoso"
        },
    ];

    for (const u of users) {
        const passwordHash = await hashPassword(u.password);
        await db.collection("petugas").doc(u.username).set({
            username: u.username,
            passwordHash,
            role: u.role,
            nama: u.nama,
        }, {
            merge: true
        });
        console.log(`Created: ${u.username} / ${u.password} (role: ${u.role})`);
    }

    console.log("\nSeed petugas selesai. Ganti password di production!");
    process.exit(0);
}

seedPetugas().catch((err) => {
    console.error("Seed gagal:", err);
    process.exit(1);
});