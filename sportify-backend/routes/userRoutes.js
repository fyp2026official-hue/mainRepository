const express = require("express");
const authMiddleware = require("../middleware/authMiddleware");
const User = require("../models/User");
const admin = require("../config/firebaseAdmin");
const MatchHistory = require("../models/MatchHistory");
const router = express.Router();

/**
 * POST /api/users/me/login
 * Creates/updates the user using Firebase token info.
 */
router.post("/me/login", authMiddleware, async (req, res) => {
  const { uid, email, name, picture } = req.firebase;

  if (!email) {
    return res.status(400).json({ message: "Firebase token missing email (check provider)" });
  }

  const user = await User.findOneAndUpdate(
    { firebaseUid: uid },
    {
      $set: {
        firebaseUid: uid,
        email,
        nameFromGoogle: name || "",
        photoURL: picture || "",
        lastLoginAt: new Date(),
      },
    },
    { new: true, upsert: true }
  );

  return res.json({
    message: "Login synced",
    user,
  });
});

/**
 * PUT /api/users/me/profile
 * Saves user-input profile fields.
 */
router.put("/me/profile", authMiddleware, async (req, res) => {
  const { uid } = req.firebase;

  const { name, phoneNumber, dateOfBirth, city, country } = req.body || {};

  // Basic validation (you can tighten this later)
  if (!name || !phoneNumber || !dateOfBirth || !city || !country) {
    return res.status(400).json({
      message: "Missing fields. Required: name, phoneNumber, dateOfBirth, city, country",
    });
  }

  const user = await User.findOneAndUpdate(
    { firebaseUid: uid },
    {
      $set: {
        "profile.name": name,
        "profile.phoneNumber": phoneNumber,
        "profile.dateOfBirth": dateOfBirth,
        "profile.city": city,
        "profile.country": country,
        profileCompleted: true,
      },
    },
    { new: true }
  );

  if (!user) {
    return res.status(404).json({ message: "User not found. Call /me/login first." });
  }

  return res.json({ message: "Profile updated", user });
});

/**
 * GET /api/users/me
 * Returns the current user
 */
router.get("/me", authMiddleware, async (req, res) => {
  const { uid } = req.firebase;

  const user = await User.findOne({ firebaseUid: uid });
  if (!user) return res.status(404).json({ message: "User not found" });

  return res.json({ user });
});

router.put("/me/fcm-token", authMiddleware, async (req, res) => {
  try {
    const { uid } = req.firebase;
    const { fcmToken } = req.body || {};

    if (!fcmToken) {
      return res.status(400).json({ message: "Missing fcmToken" });
    }

    const user = await User.findOneAndUpdate(
      { firebaseUid: uid },
      { $set: { fcmToken } },
      { new: true }
    );

    if (!user) {
      return res.status(404).json({ message: "User not found" });
    }

    return res.json({
      message: "FCM token saved",
      user,
    });
  } catch (err) {
    return res.status(500).json({
      message: "Failed to save FCM token",
      error: String(err),
    });
  }
});

router.get("/test-notification", async (req, res) => {
  try {
    const email = req.query.email;

    if (!email) {
      return res.status(400).json({ message: "email query is required" });
    }

    const user = await User.findOne({ email });

    if (!user || !user.fcmToken) {
      return res.status(404).json({ message: "User or FCM token not found" });
    }

    const message = {
      token: user.fcmToken,
      notification: {
        title: "Browser Test",
        body: "Your FCM notification is working 🚀",
      },
      data: {
        type: "test",
      },
    };

    const response = await admin.messaging().send(message);

    res.json({
      message: "Notification sent",
      response,
    });

  } catch (err) {
    res.status(500).json({
      message: "Error sending notification",
      error: String(err),
    });
  }
});

const { runMatchStartCheck } = require("../jobs/matchStartNotifier");

router.get("/debug-run-match-start", async (req, res) => {
  try {
    await runMatchStartCheck();
    return res.json({ message: "Match start check executed" });
  } catch (err) {
    return res.status(500).json({
      message: "Failed to run match start check",
      error: String(err),
    });
  }
});
const { runMatchEndCheck } = require("../jobs/matchEndNotifier");

router.get("/debug-run-match-end", async (req, res) => {
  try {
    await runMatchEndCheck();
    return res.json({ message: "Match end check executed" });
  } catch (err) {
    return res.status(500).json({
      message: "Failed to run match end check",
      error: String(err),
    });
  }
});
const { runNewsCheck } = require("../jobs/newsNotifier");

router.get("/debug-run-news", async (req, res) => {
  try {
    await runNewsCheck();
    return res.json({ message: "News check executed" });
  } catch (err) {
    return res.status(500).json({
      message: "Failed to run news check",
      error: String(err),
    });
  }
});

router.put("/me/notifications", authMiddleware, async (req, res) => {
  try {
    const { uid } = req.firebase;
    const { notificationsEnabled } = req.body || {};

    if (typeof notificationsEnabled !== "boolean") {
      return res.status(400).json({
        message: "notificationsEnabled must be true or false",
      });
    }

    const user = await User.findOneAndUpdate(
      { firebaseUid: uid },
      { $set: { notificationsEnabled } },
      { new: true }
    );

    if (!user) {
      return res.status(404).json({ message: "User not found" });
    }

    return res.json({
      message: "Notification preference updated",
      notificationsEnabled: user.notificationsEnabled,
    });
  } catch (err) {
    return res.status(500).json({
      message: "Failed to update notification preference",
      error: String(err),
    });
  }
});
router.post("/match-history", authMiddleware, async (req, res) => {
  try {
    const { uid, email } = req.firebase;
    const payload = req.body || {};

    if (!payload.venue || !payload.teamA || !payload.teamB) {
      return res.status(400).json({
        message: "Missing required match fields",
      });
    }

    const matchDoc = await MatchHistory.create({
      firebaseUid: uid,
      userEmail: email || "",
      venue: payload.venue || "",
      oversLimit: payload.oversLimit || 0,
      tossWinner: payload.tossWinner || "",
      tossDecision: payload.tossDecision || "",
      teamA: payload.teamA || "",
      teamB: payload.teamB || "",
      firstInningScore: payload.firstInningScore || 0,
      secondInningScore: payload.secondInningScore || 0,
      target: payload.target ?? null,
      winner: payload.winner || "",
      innings: Array.isArray(payload.innings) ? payload.innings : [],
      summary: payload.summary || {},
    });

    return res.status(201).json({
      message: "Match history saved successfully",
      match: matchDoc,
    });
  } catch (err) {
    return res.status(500).json({
      message: "Failed to save match history",
      error: String(err),
    });
  }
});
router.get("/match-history", authMiddleware, async (req, res) => {
  try {
    const { uid } = req.firebase;

    const matches = await MatchHistory.find({ firebaseUid: uid })
      .sort({ createdAt: -1 });

    return res.json({
      message: "Match history fetched successfully",
      matches,
    });
  } catch (err) {
    return res.status(500).json({
      message: "Failed to fetch match history",
      error: String(err),
    });
  }
});

module.exports = router;
