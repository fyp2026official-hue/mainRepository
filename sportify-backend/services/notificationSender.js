const admin = require("../config/firebaseAdmin")();
const User = require("../models/User");

async function sendToAllUsers({ title, body, data = {} }) {
  const users = await User.find({
    fcmToken: { $ne: "" },
    notificationsEnabled: true,
  });

  let success = 0;
  let failed = 0;

  for (const user of users) {
    try {
      await admin.messaging().send({
        token: user.fcmToken,
        notification: {
          title,
          body,
        },
        data: Object.fromEntries(
          Object.entries(data).map(([k, v]) => [k, String(v ?? "")])
        ),
      });

      success++;
    } catch (err) {
      failed++;
      console.error(`[FCM] Failed for ${user.email}:`, err?.message || err);
    }
  }

  return { success, failed, total: users.length };
}

module.exports = {
  sendToAllUsers,
};