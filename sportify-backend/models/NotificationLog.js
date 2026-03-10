const mongoose = require("mongoose");

const notificationLogSchema = new mongoose.Schema(
  {
    eventType: { type: String, required: true }, // match_start, match_end, news
    itemId: { type: String, required: true },    // gameId, articleId, url
    league: { type: String, default: "" },       // NBA, UCL
    sport: { type: String, default: "" },        // basketball, football
    meta: { type: Object, default: {} },
    sentAt: { type: Date, default: Date.now },
  },
  { timestamps: true }
);

notificationLogSchema.index(
  { eventType: 1, itemId: 1 },
  { unique: true }
);

module.exports = mongoose.model("NotificationLog", notificationLogSchema);