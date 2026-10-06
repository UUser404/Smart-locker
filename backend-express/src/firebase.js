const { initializeApp, cert, getApps } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");

if (getApps().length === 0) {
  let serviceAccount;
  if (process.env.FIREBASE_SERVICE_ACCOUNT_BASE64) {
    serviceAccount = JSON.parse(
      Buffer.from(
        process.env.FIREBASE_SERVICE_ACCOUNT_BASE64,
        "base64",
      ).toString("utf8"),
    );
  } else if (process.env.FIREBASE_SERVICE_ACCOUNT) {
    serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);
  } else {
    serviceAccount = require("../serviceAccountKey.json");
  }
  initializeApp({
    credential: cert(serviceAccount),
    projectId: serviceAccount.project_id,
  });
}

const db = getFirestore();
module.exports = { db };
