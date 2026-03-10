const express = require("express");
const axios = require("axios");

const router = express.Router();
const NBA_BASE = "https://api.sportsdata.io/v3/nba/scores/json";

function headers() {
  return { "Ocp-Apim-Subscription-Key": process.env.SPORTSDATA_KEY };
}

function normalizeSeason(input) {
  if (!input) return null;

  const s = String(input).trim();

  // If it contains a 4-digit year, use it (works for "2025REG", "2025POST", "Season 2025" etc.)
  const m = s.match(/\b(19|20)\d{2}\b/);
  if (m) return m[0];

  // If SportsData returns number already
  if (/^\d+$/.test(s)) return s;

  return null;
}

async function getCurrentSeason() {
  try {
    const r = await axios.get(`${NBA_BASE}/CurrentSeason`, { headers: headers() });
    console.log("📅 CurrentSeason raw:", r.data);

    const season = normalizeSeasonForStandings(r.data);
    if (season) return season;
  } catch (e) {
    console.log("⚠️ CurrentSeason failed:", e?.response?.data || e.message);
  }

  // ✅ fallback to current year
  const y = new Date().getFullYear();
  return String(y);
}

async function fetchTeamsMap() {
  const teamsResp = await axios.get(`${NBA_BASE}/teams`, { headers: headers() });

  console.log("🏀 Teams API response (first 3 only):");
  console.log(teamsResp.data.slice(0, 3)); // avoid huge dump

  const teams = Array.isArray(teamsResp.data) ? teamsResp.data : [];
  const map = new Map();
  for (const t of teams) {
    if (t?.Key) map.set(String(t.Key).toUpperCase(), t);
  }
  return map;
}

router.get("/", async (req, res) => {
  try {
    if (!process.env.SPORTSDATA_KEY) {
      return res.status(500).json({ error: "SPORTSDATA_KEY missing in .env" });
    }

let season = normalizeSeason(req.query.season);
if (!season) season = await getCurrentSeason();

if (!season) {
  return res.status(400).json({ error: "Could not determine a valid season" });
}

console.log("✅ Season being used:", season);

    let standingsResp;
    try {
      standingsResp = await axios.get(`${NBA_BASE}/Standings/${season}`, {
        headers: headers(),
      });
    } catch (e) {
      console.log("⚠️ Season failed, trying current season fallback...");
      const current = await getCurrentSeason();
      season = current;
      standingsResp = await axios.get(`${NBA_BASE}/Standings/${season}`, {
        headers: headers(),
      });
    }

    // 🔥 FULL RAW DATA (if you want everything)
    console.log("📊 RAW STANDINGS DATA:");
    console.log(JSON.stringify(standingsResp.data, null, 2));

    const teamsByKey = await fetchTeamsMap();

    const raw = Array.isArray(standingsResp.data)
      ? standingsResp.data
      : [];

    const transformed = raw.map((s) => {
      const key = String(s.Key || "").toUpperCase();
      const team = teamsByKey.get(key);

      const wins = s.Wins ?? null;
      const losses = s.Losses ?? null;
      const games =
        s.Games ?? (wins != null && losses != null ? wins + losses : null);

      const rank =
        s.Percentage ??
        null;

      return {
        rank: rank != null ? String(rank) : "-",
        points: null,
        team: {
          name: s.Name || team?.Name || key || "Team",
          logo: team?.WikipediaLogoUrl || null
        },
        all: { played: games, win: wins, draw: 0, lose: losses },
      };
    });

    return res.json({
      meta: { seasonUsed: season },
      response: [{ league: { standings: [transformed] } }],
    });
  } catch (err) {
    console.error("❌ NBA standings error:");
    console.error(err?.response?.data || err.message);
    return res.status(500).json({ error: "Failed to fetch NBA standings" });
  }
});

module.exports = router;