/**
 * NBA Fixtures Router (SportsDataIO) — FULL MODIFIED CODE
 * Adds:
 *  ✅ Request logging (route hits)
 *  ✅ SportsDataIO response logging (counts + small samples)
 *  ✅ Outgoing API response logging (counts + sample fixture)
 *  ✅ Safer error logging (status + body snippet)
 *
 * Routes:
 *  GET /default
 *  GET /completed
 *  GET /by-date?date=YYYY-MM-DD
 */

const express = require("express");
const axios = require("axios");

const router = express.Router();

const NBA_BASE = "https://api.sportsdata.io/v3/nba/scores/json";

function apiKey() {
  return process.env.SPORTSDATA_KEY;
}

// SportsDataIO supports API key via header OR query param.
function authConfig(extraParams = {}) {
  const key = apiKey();
  const headers = key ? { "Ocp-Apim-Subscription-Key": key } : {};
  const params = !key ? { key: process.env.SPORTSDATA_KEY, ...extraParams } : extraParams;
  return { headers, params };
}

function fmtDate(d) {
  const yyyy = d.getFullYear();
  const mm = String(d.getMonth() + 1).padStart(2, "0");
  const dd = String(d.getDate()).padStart(2, "0");
  return `${yyyy}-${mm}-${dd}`;
}

function safeSnippet(x, max = 500) {
  try {
    const s = typeof x === "string" ? x : JSON.stringify(x);
    return s.length > max ? s.slice(0, max) + "..." : s;
  } catch {
    return String(x);
  }
}

// ---- Optional: logs each incoming request to this router
router.use((req, res, next) => {
  console.log(`[API] ${req.method} ${req.originalUrl}`);
  next();
});

async function fetchTeamsMap() {
  const resp = await axios.get(`${NBA_BASE}/teams`, authConfig());

  const teams = Array.isArray(resp.data) ? resp.data : [];
  console.log(`[SportsDataIO] teams -> ${teams.length}`);

  // small sample (first 1)
  if (teams.length) console.log(`[SportsDataIO] teams sample: ${safeSnippet(teams[0])}`);

  const map = new Map();
  for (const t of teams) {
    if (t?.Key) map.set(String(t.Key).toUpperCase(), t);
  }
  return map;
}

async function fetchGamesByDate(dateStr) {
  const resp = await axios.get(`${NBA_BASE}/GamesByDate/${dateStr}`, authConfig());
  const games = Array.isArray(resp.data) ? resp.data : [];

  console.log(`[SportsDataIO] GamesByDate ${dateStr} -> ${games.length} games`);
  if (games.length) console.log(`[SportsDataIO] GamesByDate sample: ${safeSnippet(games[0])}`);

  return games;
}

function toFlutterFixture(game, teamsByKey) {
  const homeKey = String(game.HomeTeam || "").toUpperCase();
  const awayKey = String(game.AwayTeam || "").toUpperCase();

  const homeTeam = teamsByKey.get(homeKey);
  const awayTeam = teamsByKey.get(awayKey);

  const homeName = homeTeam?.Name || homeKey || "Home";
  const awayName = awayTeam?.Name || awayKey || "Away";

  const homeLogo = homeTeam?.WikipediaLogoUrl || null;
  const awayLogo = awayTeam?.WikipediaLogoUrl || null;

  const homeScore = game.HomeTeamScore ?? null;
  const awayScore = game.AwayTeamScore ?? null;

  // Normalize status -> short code
  const rawStatus = String(game.Status || "").toLowerCase();
  let short = "NS";
  if (rawStatus.includes("final") || rawStatus.startsWith("f/")) short = "FT";
  else if (
    rawStatus.includes("inprogress") ||
    rawStatus.includes("in progress") ||
    rawStatus.includes("live")
  )
    short = "LIVE";
  else if (
    rawStatus.includes("scheduled") ||
    rawStatus.includes("pregame") ||
    rawStatus.includes("pre-game") ||
    rawStatus.includes("pre game") ||
    rawStatus === ""
  )
    short = "NS";

  const dateVal = game.DateTime ?? game.DateTimeUTC ?? game.Day ?? null;

  return {
    fixture: { date: dateVal, status: { short, elapsed: null } },
    teams: {
      home: { name: homeName, logo: homeLogo },
      away: { name: awayName, logo: awayLogo },
    },
    goals: { home: homeScore, away: awayScore },
  };
}

function logAxiosError(prefix, err) {
  const status = err?.response?.status;
  const data = err?.response?.data;
  if (status) {
    console.error(`${prefix} HTTP ${status} -> ${safeSnippet(data)}`);
  } else {
    console.error(`${prefix} -> ${err?.message || err}`);
  }
}

// 1) Default: LIVE today + next 2 upcoming (next 7 days scan)
router.get("/default", async (req, res) => {
  try {
    if (!apiKey()) {
      console.error("[API] SPORTSDATA_KEY is missing in .env");
      return res.status(500).json({ error: "SPORTSDATA_KEY is missing in .env" });
    }

    const teamsByKey = await fetchTeamsMap();

    const today = new Date();
    const todayStr = fmtDate(today);

    const todaysGames = await fetchGamesByDate(todayStr);

    const live = todaysGames
      .filter((g) => {
        const s = String(g.Status || "").toLowerCase();
        return s.includes("inprogress") || s.includes("in progress") || s.includes("live");
      })
      .map((g) => toFlutterFixture(g, teamsByKey));

    const upcoming = [];
    for (let i = 0; i <= 7 && upcoming.length < 2; i++) {
      const d = new Date(today);
      d.setDate(today.getDate() + i);
      const dateStr = fmtDate(d);

      const games = await fetchGamesByDate(dateStr);

      const scheduled = games
        .filter((g) => {
          const s = String(g.Status || "").toLowerCase();

          // ✅ expanded tolerance for "scheduled" type statuses
          return (
            s.includes("scheduled") ||
            s.includes("pregame") ||
            s.includes("pre-game") ||
            s.includes("pre game") ||
            s.includes("necessary") ||
            s.includes("unnecessary") ||
            s === ""
          );
        })
        .map((g) => toFlutterFixture(g, teamsByKey));

      for (const item of scheduled) {
        if (upcoming.length < 2) upcoming.push(item);
      }
    }

    const out = { response: [...live, ...upcoming] };

    console.log(`[API] GET /fixtures/default -> ${out.response.length} fixtures`);
    console.log(`[API] sample fixture -> ${safeSnippet(out.response[0] || null)}`);

    return res.json(out);
  } catch (err) {
    logAxiosError("fixtures/default error:", err);
    return res.status(500).json({ error: "Failed to fetch NBA fixtures default" });
  }
});

// 2) Completed: last 10 finals (scan backwards up to 30 days)
router.get("/completed", async (req, res) => {
  try {
    if (!apiKey()) {
      console.error("[API] SPORTSDATA_KEY is missing in .env");
      return res.status(500).json({ error: "SPORTSDATA_KEY is missing in .env" });
    }

    const teamsByKey = await fetchTeamsMap();

    const completed = [];
    const today = new Date();

    for (let i = 0; i < 30 && completed.length < 10; i++) {
      const d = new Date(today);
      d.setDate(today.getDate() - i);
      const dateStr = fmtDate(d);

      const games = await fetchGamesByDate(dateStr);

      const finals = games
        .filter((g) => {
          const s = String(g.Status || "").toLowerCase();
          return s.includes("final") || s.startsWith("f/");
        })
        .map((g) => toFlutterFixture(g, teamsByKey));

      completed.push(...finals);
    }

    completed.sort((a, b) => new Date(b.fixture.date) - new Date(a.fixture.date));

    const out = { response: completed.slice(0, 10) };

    console.log(`[API] GET /fixtures/completed -> ${out.response.length} fixtures`);
    console.log(`[API] sample fixture -> ${safeSnippet(out.response[0] || null)}`);

    return res.json(out);
  } catch (err) {
    logAxiosError("fixtures/completed error:", err);
    return res.status(500).json({ error: "Failed to fetch completed NBA fixtures" });
  }
});

// 3) By date
router.get("/by-date", async (req, res) => {
  try {
    const { date } = req.query;
    if (!date) return res.status(400).json({ error: "date is required (YYYY-MM-DD)" });
    if (!apiKey()) {
      console.error("[API] SPORTSDATA_KEY is missing in .env");
      return res.status(500).json({ error: "SPORTSDATA_KEY is missing in .env" });
    }

    const teamsByKey = await fetchTeamsMap();
    const games = await fetchGamesByDate(date);

    const list = games.map((g) => toFlutterFixture(g, teamsByKey));
    list.sort((a, b) => new Date(a.fixture.date) - new Date(b.fixture.date));

    const out = { response: list };

    console.log(`[API] GET /fixtures/by-date?date=${date} -> ${out.response.length} fixtures`);
    console.log(`[API] sample fixture -> ${safeSnippet(out.response[0] || null)}`);

    return res.json(out);
  } catch (err) {
    logAxiosError("fixtures/by-date error:", err);
    return res.status(500).json({ error: "Failed to fetch NBA fixtures by date" });
  }
});

module.exports = router;