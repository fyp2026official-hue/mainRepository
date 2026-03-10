const express = require("express");
const axios = require("axios");

const router = express.Router();

// SportsDataIO Soccer v4 base
const SOCCER_BASE = "https://api.sportsdata.io/v4/soccer/scores/json";

function headers() {
  return { "Ocp-Apim-Subscription-Key": process.env.SPORTSDATA_KEY };
}

function normalizeSeason(input) {
  if (!input) return null;
  const s = String(input).trim();
  const m = s.match(/\b(19|20)\d{2}\b/);
  if (m) return m[0];
  if (/^\d+$/.test(s)) return s;
  return null;
}

// ✅ Best-effort: pick the "table" round that actually contains standings
function pickStandingsRound(rounds) {
  if (!Array.isArray(rounds) || rounds.length === 0) return null;

  const tableWithStandings = rounds.find(
    (r) =>
      String(r?.Type || "").toLowerCase() === "table" &&
      Array.isArray(r?.Standings) &&
      r.Standings.length > 0
  );
  if (tableWithStandings) return tableWithStandings;

  const anyWithStandings = rounds.find(
    (r) => Array.isArray(r?.Standings) && r.Standings.length > 0
  );
  return anyWithStandings || null;
}

// ✅ Fetch team logos
async function fetchTeamsMap(competitionId) {
  try {
    const r = await axios.get(`${SOCCER_BASE}/Teams/${competitionId}`, {
      headers: headers(),
    });
    const teams = Array.isArray(r.data) ? r.data : [];
    const map = new Map();

    for (const t of teams) {
      if (t?.TeamId != null) map.set(String(t.TeamId), t);
    }

    return map;
  } catch (e) {
    console.log("⚠️ Teams fetch failed:", e?.response?.data || e.message);
    return new Map();
  }
}

/**
 * GET /?competitionId=3&season=2026
 */
router.get("/", async (req, res) => {
  try {
    if (!process.env.SPORTSDATA_KEY) {
      return res.status(500).json({ error: "SPORTSDATA_KEY missing in .env" });
    }

    const competitionId = String(req.query.competitionId || "3").trim();
    const season = normalizeSeason(req.query.season) || "2026";

    const url = `${SOCCER_BASE}/Standings/${competitionId}/${season}`;

    let apiResp;
    try {
      apiResp = await axios.get(url, { headers: headers() });
    } catch (e) {
      console.log("❌ Soccer standings fetch failed:", e?.response?.data || e.message);
      return res.status(500).json({ error: "Failed to fetch UEFA standings" });
    }

    const rounds = Array.isArray(apiResp.data) ? apiResp.data : [];
    const round = pickStandingsRound(rounds);

    if (!round || !Array.isArray(round.Standings) || round.Standings.length === 0) {
      return res.json({
        meta: { competitionId, seasonUsed: season, roundUsed: null },
        response: [{ league: { standings: [[]] } }],
      });
    }

    const totalStandings = round.Standings.filter(
      (s) => (s?.Scope || "Total") === "Total"
    );

    const teamsById = await fetchTeamsMap(competitionId);

    const transformed = totalStandings
      .sort((a, b) => (a?.Order ?? 9999) - (b?.Order ?? 9999))
      .map((s) => {
        const teamId = String(s.TeamId ?? "");
        const team = teamsById.get(teamId);

        const played = s.Games ?? null;
        const win = s.Wins ?? null;
        const draw = s.Draws ?? null;
        const lose = s.Losses ?? null;
        const points = s.Points ?? null;

        return {
          rank: s.Order != null ? String(s.Order) : "-",
          points,
          team: {
            id: s.TeamId ?? null, // ✅ added here
            name: s.ShortName || s.Name || "Team",
            logo: team?.WikipediaLogoUrl || team?.LogoUrl || null,
          },
          all: { played, win, draw, lose },
          goals: {
            for: s.GoalsScored ?? null,
            against: s.GoalsAgainst ?? null,
            diff: s.GoalsDifferential ?? null,
          },
        };
      });

    return res.json({
      meta: {
        competitionId,
        seasonUsed: season,
        roundUsed: {
          name: round.Name,
          type: round.Type,
          roundId: round.RoundId,
        },
      },
      response: [{ league: { standings: [transformed] } }],
    });
  } catch (err) {
    console.error("❌ UEFA standings error:", err?.response?.data || err.message);
    return res.status(500).json({ error: "Failed to fetch UEFA standings" });
  }
});

module.exports = router;