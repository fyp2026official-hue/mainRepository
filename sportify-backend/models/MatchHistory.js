const mongoose = require("mongoose");

const matchHistorySchema = new mongoose.Schema(
  {
    firebaseUid: { type: String, required: true, index: true },
    userEmail: { type: String, default: "", index: true },

    venue: { type: String, default: "" },
    oversLimit: { type: Number, default: 0 },

    tossWinner: { type: String, default: "" },
    tossDecision: { type: String, default: "" },

    teamA: { type: String, default: "" },
    teamB: { type: String, default: "" },

    firstInningScore: { type: Number, default: 0 },
    secondInningScore: { type: Number, default: 0 },
    target: { type: Number, default: null },

    winner: { type: String, default: "" },

    innings: { type: [mongoose.Schema.Types.Mixed], default: [] },
    summary: { type: mongoose.Schema.Types.Mixed, default: {} },
  },
  { timestamps: true }
);

module.exports = mongoose.model("MatchHistory", matchHistorySchema);