const mongoose = require("mongoose");

const TournamentSchema = new mongoose.Schema(
  {
    // ✅ Fields from your modal
    organizerName: { type: String, required: true, trim: true },  // "Enter Name"
    contactNo: { type: String, required: true, trim: true },      // "Contact No."
    entryFee: { type: Number, required: true, min: 0 },           // "Entry Fees"
    winningPrize: { type: Number, required: true, min: 0 },        // "Winning Prize"
    venue: { type: String, required: true, trim: true },          // "Venue with City" (text)

    // ✅ Visibility (derived from current user's city)
    city: { type: String, required: true, index: true },

    // ✅ Creator
    createdByUid: { type: String, required: true, index: true },
    createdByName: { type: String, default: "" },

    // Optional metadata
    status: { type: String, enum: ["active", "closed", "cancelled"], default: "active" },
  },
  { timestamps: true }
);

module.exports = mongoose.model("Tournament", TournamentSchema);
