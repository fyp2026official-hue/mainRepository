const router = require("express").Router();
const Tournament = require("../models/Tournament");
const User = require("../models/User"); // your existing User.js

function getUserCity(user) {
  return (user?.profile?.city || "").trim();
}

function getUserDisplayName(user) {
  return (
    (user?.profile?.name || "").trim() ||
    (user?.nameFromGoogle || "").trim() ||
    ""
  );
}

// ✅ CREATE tournament (stores modal fields separately)
router.post("/", async (req, res) => {
  try {
    const {
      firebaseUid,
      organizerName,
      contactNo,
      entryFee,
      winningPrize,
      venue,
    } = req.body;

    if (!firebaseUid) return res.status(400).json({ error: "firebaseUid is required" });

    // validate modal fields
    if (!organizerName || !contactNo || entryFee === undefined || winningPrize === undefined || !venue) {
      return res.status(400).json({
        error: "organizerName, contactNo, entryFee, winningPrize, venue are required",
      });
    }

    // number validation
    const entryFeeNum = Number(entryFee);
    const winningPrizeNum = Number(winningPrize);
    if (Number.isNaN(entryFeeNum) || entryFeeNum < 0) {
      return res.status(400).json({ error: "entryFee must be a non-negative number" });
    }
    if (Number.isNaN(winningPrizeNum) || winningPrizeNum < 0) {
      return res.status(400).json({ error: "winningPrize must be a non-negative number" });
    }

    const user = await User.findOne({ firebaseUid }).lean();
    if (!user) return res.status(404).json({ error: "User not found" });

    const city = getUserCity(user);
    if (!city) {
      return res.status(400).json({ error: "User city is missing. Complete profile first." });
    }

    const createdByName = getUserDisplayName(user);

    const t = await Tournament.create({
      organizerName: organizerName.trim(),
      contactNo: contactNo.trim(),
      entryFee: entryFeeNum,
      winningPrize: winningPrizeNum,
      venue: venue.trim(),

      city, // ✅ visibility filter
      createdByUid: firebaseUid,
      createdByName,
    });

    return res.status(201).json(t);
  } catch (e) {
    return res.status(500).json({ error: e.message });
  }
});

// ✅ LIST tournaments visible to user's city
router.get("/", async (req, res) => {
  try {
    const { firebaseUid } = req.query;
    if (!firebaseUid) return res.status(400).json({ error: "firebaseUid query is required" });

    const user = await User.findOne({ firebaseUid }).lean();
    if (!user) return res.status(404).json({ error: "User not found" });

    const city = getUserCity(user);
    if (!city) {
      return res.status(400).json({ error: "User city is missing. Complete profile first." });
    }

    const tournaments = await Tournament.find({ city })
      .sort({ createdAt: -1 })
      .lean();

    return res.json({ city, tournaments });
  } catch (e) {
    return res.status(500).json({ error: e.message });
  }
});

// ✅ DELETE (only creator)
router.delete("/:id", async (req, res) => {
  try {
    const { firebaseUid } = req.query;
    if (!firebaseUid) return res.status(400).json({ error: "firebaseUid query is required" });

    const t = await Tournament.findById(req.params.id);
    if (!t) return res.status(404).json({ error: "Tournament not found" });

    if (t.createdByUid !== firebaseUid) {
      return res.status(403).json({ error: "Not allowed (only creator can delete)" });
    }

    await Tournament.deleteOne({ _id: t._id });
    return res.json({ ok: true });
  } catch (e) {
    return res.status(500).json({ error: e.message });
  }
});

module.exports = router;