const express = require("express");
const axios = require("axios");

const router = express.Router();

const NBA_BASE = "https://api.sportsdata.io/v3/nba/scores/json";

function apiKey() {
  return process.env.SPORTSDATA_KEY;
}

function authConfig(extraParams = {}) {
  const key = apiKey();
  const headers = key ? { "Ocp-Apim-Subscription-Key": key } : {};
  const params = !key ? { key: process.env.SPORTSDATA_KEY, ...extraParams } : extraParams;
  return { headers, params };
}

function logApi(label, data) {
  try {
    if (Array.isArray(data)) {
      console.log(`[SportsDataIO] ${label} -> ${data.length}`);
      if (data.length) console.log(`[SportsDataIO] ${label} sample: ${JSON.stringify(data[0]).slice(0, 900)}`);
    } else {
      console.log(`[SportsDataIO] ${label} -> object`);
      console.log(`[SportsDataIO] ${label} sample: ${JSON.stringify(data).slice(0, 900)}`);
    }
  } catch (e) {
    console.log(`[SportsDataIO] ${label} -> (print failed)`, e.message);
  }
}

function norm(s) {
  return String(s || "").trim().toLowerCase();
}

async function fetchTeams() {
  const resp = await axios.get(`${NBA_BASE}/teams`, authConfig());
  const teams = Array.isArray(resp.data) ? resp.data : [];
  logApi("teams", teams);
  return teams;
}

// Accepts: "PHI" or "76ers" or "Philadelphia 76ers"
async function resolveTeamKey(teamIdentifier) {
  const teams = await fetchTeams();
  const id = norm(teamIdentifier);

  // 1) exact Key
  const byKey = teams.find((t) => norm(t.Key) === id);
  if (byKey?.Key) return byKey.Key;

  // 2) name (e.g. "Celtics")
  const byName = teams.find((t) => norm(t.Name) === id);
  if (byName?.Key) return byName.Key;

  // 3) full name (City + Name)
  const byFull = teams.find((t) => norm(`${t.City} ${t.Name}`) === id);
  if (byFull?.Key) return byFull.Key;

  // 4) contains fallback
  const byContains = teams.find((t) => norm(`${t.City} ${t.Name}`).includes(id));
  if (byContains?.Key) return byContains.Key;

  return null;
}

/**
 * GET /team/players/:team
 * Returns SportsDataIO PlayersBasic/{teamKey} list (same shape you pasted)
 */
router.get("/players/:team", async (req, res) => {
  try {
    console.log(`[API] GET /team/players/${req.params.team}`);

    if (!apiKey()) return res.status(500).json({ error: "SPORTSDATA_KEY is missing in .env" });

    const teamKey = await resolveTeamKey(req.params.team);
    if (!teamKey) return res.status(404).json({ error: "Team not found" });

    const resp = await axios.get(`${NBA_BASE}/PlayersBasic/${teamKey}`, authConfig());
    const players = Array.isArray(resp.data) ? resp.data : [];
    logApi(`PlayersBasic/${teamKey}`, players);

    console.log(`[API] GET /team/players/${req.params.team} -> ${players.length} players (teamKey=${teamKey})`);
    return res.json({ teamKey, response: players });
  } catch (err) {
    console.error("team/players error:", err?.response?.data || err.message);
    return res.status(500).json({ error: "Failed to fetch team players" });
  }
});

/**
 * GET /team/stats/:team?season=2025
 * Returns ONE team row from TeamSeasonStats/{season} (same shape you pasted)
 */
router.get("/stats/:team", async (req, res) => {
  try {
    console.log(`[API] GET /team/stats/${req.params.team} ${req.originalUrl}`);

    if (!apiKey()) return res.status(500).json({ error: "SPORTSDATA_KEY is missing in .env" });

    const season = req.query.season;
    if (!season) return res.status(400).json({ error: "season is required, e.g. ?season=2025" });

    const teams = await fetchTeams();
    const teamKey = await resolveTeamKey(req.params.team);
    if (!teamKey) return res.status(404).json({ error: "Team not found" });

    const teamObj = teams.find((t) => String(t.Key).toUpperCase() === String(teamKey).toUpperCase());
    const teamId = teamObj?.TeamID;

    const statsResp = await axios.get(`${NBA_BASE}/TeamSeasonStats/${season}`, authConfig());
    const allStats = Array.isArray(statsResp.data) ? statsResp.data : [];
    logApi(`TeamSeasonStats/${season}`, allStats);

    // Find by TeamID, else by Team (key)
    const row =
      allStats.find((s) => s.TeamID === teamId) ||
      allStats.find((s) => String(s.Team || "").toUpperCase() === String(teamKey).toUpperCase()) ||
      null;

    console.log(
      `[API] GET /team/stats/${req.params.team}?season=${season} -> ${row ? "FOUND" : "NOT FOUND"} (teamKey=${teamKey}, teamId=${teamId})`
    );

    return res.json({
      teamKey,
      team: teamObj || null,
      response: row, // <- this matches the big object you pasted
    });
  } catch (err) {
    console.error("team/stats error:", err?.response?.data || err.message);
    return res.status(500).json({ error: "Failed to fetch team season stats" });
  }
});

module.exports = router;