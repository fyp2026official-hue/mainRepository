const admin = require("firebase-admin");
const path = require("path");

function initFirebaseAdmin() {
  const keyPath = process.env.FIREBASE_SERVICE_ACCOUNT_PATH;
  if (!keyPath) throw new Error("FIREBASE_SERVICE_ACCOUNT_PATH missing in .env");

  const fullPath = path.resolve(keyPath);

  if (!admin.apps.length) {
    admin.initializeApp({
      credential: admin.credential.cert(require(fullPath)),
    });
  }

  console.log("✅ Firebase Admin initialized");
  return admin;
}

module.exports = initFirebaseAdmin;
