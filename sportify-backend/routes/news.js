// routes/news.js
const express = require("express");
const axios = require("axios");

const router = express.Router();

const BASE = "https://api.sportsdata.io/v3/nba/news-rotoballer";

function apiKey() {
  return process.env.SPORTSDATA_KEY;
}

function authConfig() {
  const key = apiKey();
  const headers = key ? { "Ocp-Apim-Subscription-Key": key } : {};
  // fallback to query param if header key missing (still supports it)
  const params = !key ? { key: process.env.SPORTSDATA_KEY } : {};
  return { headers, params };
}

// Convert "YYYY-MM-DD" -> "YYYY-MMM-DD" (e.g., 2026-02-28 -> 2026-FEB-28)
function toSportsDataDate(ymd) {
  // expect YYYY-MM-DD
  const [yyyy, mm, dd] = String(ymd || "").split("-");
  if (!yyyy || !mm || !dd) return null;

  const monthNames = [
    "JAN", "FEB", "MAR", "APR", "MAY", "JUN",
    "JUL", "AUG", "SEP", "OCT", "NOV", "DEC",
  ];

  const m = Number(mm);
  if (!m || m < 1 || m > 12) return null;

  return `${yyyy}-${monthNames[m - 1]}-${dd}`;
}

/**
 * GET /news/premium?date=YYYY-MM-DD
 * Response: { response: [ ...newsItems ] }
 */
router.get("/premium", async (req, res) => {
  try {
    console.log("[API] GET /news/premium", req.query);

    if (!apiKey()) {
      return res.status(500).json({ error: "SPORTSDATA_KEY is missing in .env" });
    }

    const dateQ = req.query.date || "";
    const sdDate = toSportsDataDate(dateQ);

    if (!sdDate) {
      return res.status(400).json({
        error: "date is required in YYYY-MM-DD format (example: 2026-02-28)",
      });
    }

    const url = `${BASE}/json/RotoBallerPremiumNewsByDate/${sdDate}`;
    const resp = await axios.get(url, authConfig());

    const items = Array.isArray(resp.data) ? resp.data : [];

    // ✅ print API response info in terminal
    console.log(`[SportsDataIO] PremiumNewsByDate ${sdDate} -> ${items.length} items`);
    if (items.length > 0) {
      console.log("[SportsDataIO] sample:", JSON.stringify(items[0]).slice(0, 500));
    }

    return res.json({ response: items });
  } catch (err) {
    console.error(
      "news/premium error:",
      err?.response?.data || err.message
    );
    return res.status(500).json({ error: "Failed to fetch premium news by date" });
  }
});

module.exports = router;