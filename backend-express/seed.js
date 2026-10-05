const { initializeApp, cert } = require("firebase-admin/app");
const { getFirestore, Timestamp } = require("firebase-admin/firestore");
const serviceAccount = require("./serviceAccountKey.json");

initializeApp({
  credential: cert(serviceAccount),
  projectId: serviceAccount.project_id,
});

const db = getFirestore();

async function seed() {
  await db.collection("lockers").doc("locker1").set(
    {
      status: "empty",
      currentQrToken: "TESTTOKEN",
      qrTokenGeneratedAt: Timestamp.now(),
      qrTokenFrozen: false,
      currentRentalId: null,
      pendingCommand: null,
    },
    { merge: true },
  );

  console.log("Seed locker1 berhasil. Token: TESTTOKEN");
}

seed()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error("Seed gagal:", err);
    process.exit(1);
  });
