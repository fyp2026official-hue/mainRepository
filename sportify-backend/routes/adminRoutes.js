const express = require("express");
const bcrypt = require("bcrypt");
const jwt = require("jsonwebtoken");
const initFirebaseAdmin = require("../config/firebaseAdmin");
const User = require("../models/User");
const Tournament = require("../models/Tournament");
const MatchHistory = require("../models/MatchHistory");
const NotificationLog = require("../models/NotificationLog");
const AuditLog = require("../models/AuditLog");
const adminAuthMiddleware = require("../middleware/adminAuthMiddleware");

const router = express.Router();
const firebaseAdmin = initFirebaseAdmin();

function escapeRegex(value) {
  return String(value || "").replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

function pagination(query) {
  const page = Math.max(parseInt(query.page, 10) || 1, 1);
  const limit = Math.min(Math.max(parseInt(query.limit, 10) || 20, 1), 100);
  return { page, limit, skip: (page - 1) * limit };
}

function parseBoolean(value) {
  if (value === undefined) return undefined;
  if (value === true || value === "true") return true;
  if (value === false || value === "false") return false;
  return undefined;
}

function dateRange(dateValue) {
  if (!dateValue) return null;
  const start = new Date(`${dateValue}T00:00:00.000Z`);
  if (Number.isNaN(start.getTime())) return null;
  const end = new Date(start);
  end.setUTCDate(end.getUTCDate() + 1);
  return { $gte: start, $lt: end };
}

function cleanUser(user) {
  if (!user) return null;
  const value = user.toObject ? user.toObject() : user;
  delete value.adminPasswordHash;
  delete value.fcmToken;
  return value;
}

function cleanAdmin(user) {
  return {
    id: user._id,
    firebaseUid: user.firebaseUid,
    email: user.email,
    role: user.role,
    isActive: user.isActive,
    name: user.profile?.name || user.nameFromGoogle || "",
    photoURL: user.photoURL || "",
    profileCompleted: user.profileCompleted,
  };
}

async function audit(req, action, entityType, entityId, before, after, meta = {}) {
  try {
    await AuditLog.create({
      adminUserId: req.adminUser?._id,
      adminEmail: req.adminUser?.email || "",
      action,
      entityType,
      entityId: String(entityId || ""),
      before,
      after,
      meta,
    });
  } catch (err) {
    console.error("[AUDIT] Failed:", err?.message || err);
  }
}

router.post("/auth/login", async (req, res) => {
  try {
    const { email, password } = req.body || {};
    if (!email || !password) {
      return res.status(400).json({ message: "email and password are required" });
    }

    const secret = process.env.ADMIN_JWT_SECRET || process.env.JWT_SECRET;
    if (!secret) return res.status(500).json({ message: "Admin JWT secret is not configured" });

    const normalizedEmail = String(email).trim();
    const user = await User.findOne({
      email: new RegExp(`^${escapeRegex(normalizedEmail)}$`, "i"),
    }).select("+adminPasswordHash");

    if (!user || user.role !== "admin" || user.isActive === false || !user.adminPasswordHash) {
      return res.status(403).json({ message: "Invalid credentials or admin access denied" });
    }

    const passwordOk = await bcrypt.compare(password, user.adminPasswordHash);
    if (!passwordOk) {
      return res.status(403).json({ message: "Invalid credentials or admin access denied" });
    }

    const token = jwt.sign(
      { sub: user._id.toString(), email: user.email, role: user.role },
      secret,
      { expiresIn: process.env.ADMIN_JWT_EXPIRES_IN || "8h" }
    );

    return res.json({ token, admin: cleanAdmin(user) });
  } catch (err) {
    return res.status(500).json({ message: "Admin login failed", error: String(err) });
  }
});

router.use(adminAuthMiddleware);

router.get("/dashboard", async (req, res) => {
  try {
    const [
      totalUsers,
      completedProfilesCount,
      totalTournaments,
      tournamentsByStatus,
      totalMatchHistories,
      totalNotificationLogs,
    ] = await Promise.all([
      User.countDocuments(),
      User.countDocuments({ profileCompleted: true }),
      Tournament.countDocuments(),
      Tournament.aggregate([{ $group: { _id: "$status", count: { $sum: 1 } } }, { $sort: { _id: 1 } }]),
      MatchHistory.countDocuments(),
      NotificationLog.countDocuments(),
    ]);

    return res.json({
      stats: {
        totalUsers,
        completedProfilesCount,
        incompleteProfilesCount: totalUsers - completedProfilesCount,
        totalTournaments,
        tournamentsByStatus: tournamentsByStatus.reduce((acc, item) => {
          acc[item._id || "unknown"] = item.count;
          return acc;
        }, {}),
        totalMatchHistories,
        totalNotificationLogs,
      },
    });
  } catch (err) {
    return res.status(500).json({ message: "Failed to fetch admin dashboard stats", error: String(err) });
  }
});

router.get("/users", async (req, res) => {
  try {
    const { page, limit, skip } = pagination(req.query);
    const filter = {};
    if (req.query.city) filter["profile.city"] = new RegExp(`^${escapeRegex(req.query.city)}$`, "i");
    const profileCompleted = parseBoolean(req.query.profileCompleted);
    if (profileCompleted !== undefined) filter.profileCompleted = profileCompleted;
    const isActive = parseBoolean(req.query.isActive);
    if (isActive !== undefined) filter.isActive = isActive;
    if (req.query.search) {
      const search = new RegExp(escapeRegex(req.query.search), "i");
      filter.$or = [
        { email: search },
        { nameFromGoogle: search },
        { "profile.name": search },
        { "profile.phoneNumber": search },
        { firebaseUid: search },
      ];
    }

    const [users, totalCount] = await Promise.all([
      User.find(filter).select("-fcmToken").sort({ createdAt: -1 }).skip(skip).limit(limit).lean(),
      User.countDocuments(filter),
    ]);
    return res.json({ users, pagination: { page, limit, totalCount, totalPages: Math.ceil(totalCount / limit) } });
  } catch (err) {
    return res.status(500).json({ message: "Failed to fetch admin users", error: String(err) });
  }
});

router.get("/users/:id", async (req, res) => {
  try {
    const user = await User.findById(req.params.id).select("-fcmToken").lean();
    if (!user) return res.status(404).json({ message: "User not found" });
    return res.json({ user });
  } catch (err) {
    return res.status(500).json({ message: "Failed to fetch user", error: String(err) });
  }
});

router.patch("/users/:id", async (req, res) => {
  try {
    const updates = {};
    if (req.body.role !== undefined) {
      if (!["user", "admin"].includes(req.body.role)) {
        return res.status(400).json({ message: "role must be user or admin" });
      }
      updates.role = req.body.role;
    }
    if (req.body.isActive !== undefined) {
      if (typeof req.body.isActive !== "boolean") {
        return res.status(400).json({ message: "isActive must be boolean" });
      }
      updates.isActive = req.body.isActive;
    }
    if (Object.keys(updates).length === 0) return res.status(400).json({ message: "No valid fields to update" });

    const beforeDoc = await User.findById(req.params.id).select("-fcmToken").lean();
    if (!beforeDoc) return res.status(404).json({ message: "User not found" });

    const user = await User.findByIdAndUpdate(req.params.id, { $set: updates }, { new: true })
      .select("-fcmToken")
      .lean();

    await audit(req, "update_user", "user", req.params.id, beforeDoc, user);
    return res.json({ message: "User updated", user });
  } catch (err) {
    return res.status(500).json({ message: "Failed to update user", error: String(err) });
  }
});

router.get("/tournaments", async (req, res) => {
  try {
    const { page, limit, skip } = pagination(req.query);
    const filter = {};
    if (req.query.city) filter.city = new RegExp(`^${escapeRegex(req.query.city)}$`, "i");
    if (req.query.status) filter.status = req.query.status;
    if (req.query.search) {
      const search = new RegExp(escapeRegex(req.query.search), "i");
      filter.$or = [
        { organizerName: search },
        { contactNo: search },
        { venue: search },
        { createdByName: search },
        { createdByUid: search },
      ];
    }

    const [tournaments, totalCount] = await Promise.all([
      Tournament.find(filter).sort({ createdAt: -1 }).skip(skip).limit(limit).lean(),
      Tournament.countDocuments(filter),
    ]);
    return res.json({ tournaments, pagination: { page, limit, totalCount, totalPages: Math.ceil(totalCount / limit) } });
  } catch (err) {
    return res.status(500).json({ message: "Failed to fetch admin tournaments", error: String(err) });
  }
});

router.get("/tournaments/:id", async (req, res) => {
  try {
    const tournament = await Tournament.findById(req.params.id).lean();
    if (!tournament) return res.status(404).json({ message: "Tournament not found" });
    return res.json({ tournament });
  } catch (err) {
    return res.status(500).json({ message: "Failed to fetch tournament", error: String(err) });
  }
});

router.patch("/tournaments/:id", async (req, res) => {
  try {
    const allowed = ["organizerName", "contactNo", "entryFee", "winningPrize", "venue", "city", "status"];
    const updates = {};
    for (const field of allowed) {
      if (req.body[field] !== undefined) updates[field] = req.body[field];
    }
    if (updates.status && !["active", "closed", "cancelled"].includes(updates.status)) {
      return res.status(400).json({ message: "status must be active, closed, or cancelled" });
    }
    if (updates.entryFee !== undefined) updates.entryFee = Number(updates.entryFee);
    if (updates.winningPrize !== undefined) updates.winningPrize = Number(updates.winningPrize);
    if (Number.isNaN(updates.entryFee) || Number.isNaN(updates.winningPrize)) {
      return res.status(400).json({ message: "entryFee and winningPrize must be numbers" });
    }
    if (Object.keys(updates).length === 0) return res.status(400).json({ message: "No valid fields to update" });

    const beforeDoc = await Tournament.findById(req.params.id).lean();
    if (!beforeDoc) return res.status(404).json({ message: "Tournament not found" });

    const tournament = await Tournament.findByIdAndUpdate(req.params.id, { $set: updates }, {
      new: true,
      runValidators: true,
    }).lean();

    await audit(req, "update_tournament", "tournament", req.params.id, beforeDoc, tournament);
    return res.json({ message: "Tournament updated", tournament });
  } catch (err) {
    return res.status(500).json({ message: "Failed to update tournament", error: String(err) });
  }
});

router.delete("/tournaments/:id", async (req, res) => {
  try {
    const tournament = await Tournament.findById(req.params.id).lean();
    if (!tournament) return res.status(404).json({ message: "Tournament not found" });
    await Tournament.deleteOne({ _id: req.params.id });
    await audit(req, "delete_tournament", "tournament", req.params.id, tournament, null);
    return res.json({ message: "Tournament deleted", ok: true });
  } catch (err) {
    return res.status(500).json({ message: "Failed to delete tournament", error: String(err) });
  }
});

router.get("/matches", async (req, res) => {
  try {
    const { page, limit, skip } = pagination(req.query);
    const filter = {};
    if (req.query.search) {
      const search = new RegExp(escapeRegex(req.query.search), "i");
      filter.$or = [{ firebaseUid: search }, { userEmail: search }, { teamA: search }, { teamB: search }, { winner: search }];
    }
    if (req.query.email) filter.userEmail = new RegExp(escapeRegex(req.query.email), "i");
    if (req.query.venue) filter.venue = new RegExp(escapeRegex(req.query.venue), "i");
    const createdAt = dateRange(req.query.date);
    if (createdAt) filter.createdAt = createdAt;

    const [matches, totalCount] = await Promise.all([
      MatchHistory.find(filter).sort({ createdAt: -1 }).skip(skip).limit(limit).lean(),
      MatchHistory.countDocuments(filter),
    ]);
    return res.json({ matches, pagination: { page, limit, totalCount, totalPages: Math.ceil(totalCount / limit) } });
  } catch (err) {
    return res.status(500).json({ message: "Failed to fetch admin matches", error: String(err) });
  }
});

router.get("/matches/:id", async (req, res) => {
  try {
    const match = await MatchHistory.findById(req.params.id).lean();
    if (!match) return res.status(404).json({ message: "Match history not found" });
    return res.json({ match });
  } catch (err) {
    return res.status(500).json({ message: "Failed to fetch match history", error: String(err) });
  }
});

router.delete("/matches/:id", async (req, res) => {
  try {
    const match = await MatchHistory.findById(req.params.id).lean();
    if (!match) return res.status(404).json({ message: "Match history not found" });
    await MatchHistory.deleteOne({ _id: req.params.id });
    await audit(req, "delete_match", "match_history", req.params.id, match, null);
    return res.json({ message: "Match history deleted", ok: true });
  } catch (err) {
    return res.status(500).json({ message: "Failed to delete match history", error: String(err) });
  }
});

router.get("/notifications/logs", async (req, res) => {
  try {
    const { page, limit, skip } = pagination(req.query);
    const filter = {};
    if (req.query.eventType) filter.eventType = req.query.eventType;
    if (req.query.search) {
      const search = new RegExp(escapeRegex(req.query.search), "i");
      filter.$or = [{ itemId: search }, { league: search }, { sport: search }];
    }
    const [logs, totalCount] = await Promise.all([
      NotificationLog.find(filter).sort({ createdAt: -1 }).skip(skip).limit(limit).lean(),
      NotificationLog.countDocuments(filter),
    ]);
    return res.json({ logs, pagination: { page, limit, totalCount, totalPages: Math.ceil(totalCount / limit) } });
  } catch (err) {
    return res.status(500).json({ message: "Failed to fetch notification logs", error: String(err) });
  }
});

router.post("/notifications/send", async (req, res) => {
  try {
    const { title, body, city } = req.body || {};
    if (!title || !body) return res.status(400).json({ message: "title and body are required" });

    const filter = { fcmToken: { $ne: "" }, notificationsEnabled: true, isActive: { $ne: false } };
    if (city) filter["profile.city"] = new RegExp(`^${escapeRegex(city)}$`, "i");
    const users = await User.find(filter).select("email fcmToken");

    let success = 0;
    let failed = 0;
    for (const user of users) {
      try {
        await firebaseAdmin.messaging().send({
          token: user.fcmToken,
          notification: { title, body },
          data: { type: "admin_manual", city: String(city || "") },
        });
        success++;
      } catch (err) {
        failed++;
        console.error(`[ADMIN FCM] Failed for ${user.email}:`, err?.message || err);
      }
    }

    const log = await NotificationLog.create({
      eventType: "admin_manual",
      itemId: `admin_manual_${Date.now()}_${Math.random().toString(16).slice(2)}`,
      league: "",
      sport: "",
      meta: { title, body, city: city || "", success, failed, total: users.length },
      sentAt: new Date(),
    });

    await audit(req, "send_notification", "notification", log._id, null, {
      title,
      body,
      city: city || "",
      success,
      failed,
      total: users.length,
    });

    return res.status(201).json({ message: "Notification send completed", result: { success, failed, total: users.length }, log });
  } catch (err) {
    return res.status(500).json({ message: "Failed to send notification", error: String(err) });
  }
});

module.exports = router;
