const { db } = require("./src/firebase");
const { generateToken } = require("./src/services/qrTokenService");

// Untuk testing: token berlaku 1 jam (bukan 60 detik), biar gampang
const TEST_TOKEN_VALID_MS = 60 * 60 * 1000;

async function seed() {
  const now = Date.now();
  const lockers = ["locker_01", "locker_02", "locker_03", "locker_04"];

  for (let i = 0; i < lockers.length; i++) {
    const lockerId = lockers[i];
    const lockerRef = db.collection("lockers").doc(lockerId);
    const existing = await lockerRef.get();
    const existingData = existing.exists ? existing.data() : {};

    // Reset token tiap seed, supaya bisa langsung dipakai test
    const token = generateToken();
    const qrTokens = [
      { token, generatedAt: now, expiresAt: now + TEST_TOKEN_VALID_MS },
    ];

    await lockerRef.set(
      {
        status: existingData.status === "occupied" ? "occupied" : "empty",
        currentRentalId: existingData.currentRentalId || null,
        qrTokens,
        qrTokenFrozen: existingData.status === "occupied",
        unlockedSince: null,
        pendingCommand: null,
        pendingEnd: false,
        controllerId: "esp32_01",
        lockerIndex: i,
      },
      { merge: true },
    );

    console.log(`${lockerId}: token=${token}`);
  }

  console.log("\nSeed selesai. Simpan token di atas untuk test.");
  process.exit(0);
}

seed().catch((err) => {
  console.error("Seed gagal:", err);
  process.exit(1);
});
