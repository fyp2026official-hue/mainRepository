/**
 * nba_match_details.routes.js
 * ------------------------------------------------------------
 * ONE FILE that exposes 2 endpoints:
 * 1) GET /api/nba/h2h?home=NY&away=SA
 *    - calls Odds MatchupTrends and computes head-to-head from PreviousGames
 *
 * 2) GET /api/nba/starting-lineups?date=2026-03-01&home=NY&away=SA
 *    - calls Projections StartingLineupsByDate and returns lineup(s)
 *    - if home/away provided, returns only that matchup, else returns all games on date
 *
 * 3) GET /api/nba/match-details?date=2026-03-01&home=NY&away=SA
 *    - combines BOTH: { h2h, lineups }
 *
 * Requirements:
 * - Node 18+ (has global fetch). If Node <18, use node-fetch.
 */

const express = require("express");
const router = express.Router();

const SPORTSDATA_KEY = process.env.SPORTSDATA_KEY;

const BASE_ODDS = "https://api.sportsdata.io/v3/nba/odds/json";
const BASE_PROJ = "https://api.sportsdata.io/v3/nba/projections/json";

function safeUpper(v) {
  return (v ?? "").toString().trim().toUpperCase();
}

function parseDateIso(raw) {
  if (!raw) return null;
  const d = new Date(raw);
  return Number.isNaN(d.getTime()) ? raw.toString() : d.toISOString();
}

function calcWinner(g) {
  const hs = g?.HomeTeamScore;
  const as = g?.AwayTeamScore;
  if (typeof hs !== "number" || typeof as !== "number") return null;
  if (hs > as) return g.HomeTeam;
  if (as > hs) return g.AwayTeam;
  return "TIE";
}

function computeH2H(previousGames, home, away) {
  const HOME = safeUpper(home);
  const AWAY = safeUpper(away);

  let homeWins = 0;
  let awayWins = 0;
  let ties = 0;

  const games = (Array.isArray(previousGames) ? previousGames : [])
    .filter((g) => {
      const ht = safeUpper(g?.HomeTeam);
      const at = safeUpper(g?.AwayTeam);
      return (ht === HOME && at === AWAY) || (ht === AWAY && at === HOME);
    })
    .map((g) => {
      const winner = calcWinner(g);
      return {
        gameId: g?.GameID ?? null,
        season: g?.Season ?? null,
        seasonType: g?.SeasonType ?? null,
        status: g?.Status ?? null,
        date: parseDateIso(g?.DateTimeUTC || g?.DateTime || g?.Day),
        homeTeam: safeUpper(g?.HomeTeam),
        awayTeam: safeUpper(g?.AwayTeam),
        homeScore: typeof g?.HomeTeamScore === "number" ? g.HomeTeamScore : null,
        awayScore: typeof g?.AwayTeamScore === "number" ? g.AwayTeamScore : null,
        winner: winner ? safeUpper(winner) : null,
      };
    })
    .sort((a, b) => {
      const da = a.date ? new Date(a.date).getTime() : 0;
      const db = b.date ? new Date(b.date).getTime() : 0;
      return db - da;
    });

  for (const g of games) {
    if (!g.winner) continue;
    if (g.winner === "TIE") {
      ties++;
      continue;
    }
    if (g.winner === HOME) homeWins++;
    else if (g.winner === AWAY) awayWins++;
  }

  return {
    home: HOME,
    away: AWAY,
    homeWins,
    awayWins,
    ties,
    totalGames: games.length,
    lastGames: games.slice(0, 10),
  };
}

/** Fetch Odds MatchupTrends for home/away and return {previousGames, raw} */
async function fetchMatchupTrends(home, away) {
  const url = `${BASE_ODDS}/MatchupTrends/${encodeURIComponent(home)}/${encodeURIComponent(
    away
  )}?key=${encodeURIComponent(SPORTSDATA_KEY)}`;

  const r = await fetch(url);
  const text = await r.text();
  if (!r.ok) {
    throw new Error(`MatchupTrends failed (${r.status}): ${text.slice(0, 300)}`);
  }
  const data = JSON.parse(text);
  return {
    raw: data,
    previousGames: data?.PreviousGames ?? [],
  };
}

/** Fetch StartingLineupsByDate and return array */
async function fetchStartingLineupsByDate(dateStr) {
  const url = `${BASE_PROJ}/StartingLineupsByDate/${encodeURIComponent(
    dateStr
  )}?key=${encodeURIComponent(SPORTSDATA_KEY)}`;

  const r = await fetch(url);
  const text = await r.text();
  if (!r.ok) {
    throw new Error(
      `StartingLineupsByDate failed (${r.status}): ${text.slice(0, 300)}`
    );
  }
  return JSON.parse(text);
}

function simplifyLineupPlayer(p) {
  return {
    playerId: p?.PlayerID ?? null,
    firstName: p?.FirstName ?? null,
    lastName: p?.LastName ?? null,
    position: p?.Position ?? null,
    starting: !!p?.Starting,
    confirmed: !!p?.Confirmed,
    lineupStatus: p?.LineupStatus ?? null,
    team: safeUpper(p?.Team),
    teamId: p?.TeamID ?? null,
  };
}

function simplifyGameLineups(game) {
  const homeTeam = safeUpper(game?.HomeTeam);
  const awayTeam = safeUpper(game?.AwayTeam);

  const homeLineup = Array.isArray(game?.HomeLineup) ? game.HomeLineup : [];
  const awayLineup = Array.isArray(game?.AwayLineup) ? game.AwayLineup : [];

  return {
    gameId: game?.GameID ?? null,
    status: game?.Status ?? null,
    dateTime: parseDateIso(game?.DateTime || game?.Day),
    homeTeam,
    awayTeam,
    homeStarters: homeLineup.filter((p) => p?.Starting).map(simplifyLineupPlayer),
    awayStarters: awayLineup.filter((p) => p?.Starting).map(simplifyLineupPlayer),
    homeBench: homeLineup.filter((p) => !p?.Starting).map(simplifyLineupPlayer),
    awayBench: awayLineup.filter((p) => !p?.Starting).map(simplifyLineupPlayer),
    // if you need original arrays, keep them too:
    // rawHomeLineup: homeLineup,
    // rawAwayLineup: awayLineup,
  };
}

function findGameByTeams(games, home, away) {
  const HOME = safeUpper(home);
  const AWAY = safeUpper(away);

  return (Array.isArray(games) ? games : []).find((g) => {
    const ht = safeUpper(g?.HomeTeam);
    const at = safeUpper(g?.AwayTeam);
    return ht === HOME && at === AWAY;
  });
}

/**
 * GET /api/nba/h2h?home=NY&away=SA
 */
router.get("/h2h", async (req, res) => {
  try {
    const home = safeUpper(req.query.home);
    const away = safeUpper(req.query.away);

    if (!home || !away) {
      return res.status(400).json({ error: "Use ?home=NY&away=SA" });
    }

    const { previousGames } = await fetchMatchupTrends(home, away);
    const h2h = computeH2H(previousGames, home, away);

    return res.json({ response: h2h });
  } catch (err) {
    console.error("H2H error:", err);
    return res.status(500).json({ error: "Internal server error" });
  }
});

/**
 * GET /api/nba/starting-lineups?date=2026-03-01
 * Optional: &home=NY&away=SA  -> returns only that matchup lineups (if found)
 */
router.get("/starting-lineups", async (req, res) => {
  try {
    const dateStr = (req.query.date ?? "").toString().trim();
    if (!dateStr) return res.status(400).json({ error: "Use ?date=YYYY-MM-DD" });

    const home = req.query.home ? safeUpper(req.query.home) : null;
    const away = req.query.away ? safeUpper(req.query.away) : null;

    const games = await fetchStartingLineupsByDate(dateStr);

    // If no teams provided, return all games simplified
    if (!home || !away) {
      const simplified = games.map(simplifyGameLineups);
      return res.json({
        response: {
          date: dateStr,
          totalGames: simplified.length,
          games: simplified,
        },
      });
    }

    // Return only specific matchup
    const match = findGameByTeams(games, home, away);
    if (!match) {
      return res.status(404).json({
        error: "Match not found on this date",
        response: { date: dateStr, home, away },
      });
    }

    return res.json({
      response: {
        date: dateStr,
        game: simplifyGameLineups(match),
      },
    });
  } catch (err) {
    console.error("Lineups error:", err);
    return res.status(500).json({ error: "Internal server error" });
  }
});

/**
 * ✅ Combined endpoint
 * GET /api/nba/match-details?date=2026-03-01&home=NY&away=SA
 * Returns: { h2h, lineups }
 */
router.get("/match-details", async (req, res) => {
  try {
    const dateStr = (req.query.date ?? "").toString().trim();
    const home = safeUpper(req.query.home);
    const away = safeUpper(req.query.away);

    if (!dateStr || !home || !away) {
      return res
        .status(400)
        .json({ error: "Use ?date=YYYY-MM-DD&home=NY&away=SA" });
    }

    // Run both requests in parallel
    const [matchup, games] = await Promise.all([
      fetchMatchupTrends(home, away),
      fetchStartingLineupsByDate(dateStr),
    ]);

    const h2h = computeH2H(matchup.previousGames, home, away);

    const match = findGameByTeams(games, home, away);
    const lineups = match ? simplifyGameLineups(match) : null;

    return res.json({
      response: {
        date: dateStr,
        home,
        away,
        h2h,
        lineups, // null if not found on date
      },
    });
  } catch (err) {
    console.error("Match details error:", err);
    return res.status(500).json({ error: "Internal server error" });
  }
});

module.exports = router;