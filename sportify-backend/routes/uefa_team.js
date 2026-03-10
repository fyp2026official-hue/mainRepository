const express = require("express");
const axios = require("axios");

const router = express.Router();

const SOCCER_BASE = "https://api.sportsdata.io/v4/soccer/scores/json";

function apiKey() {
  return process.env.SPORTSDATA_KEY;
}

function authConfig(extraParams = {}) {
  const key = apiKey();
  const headers = key ? { "Ocp-Apim-Subscription-Key": key } : {};
  const params = !key
    ? { key: process.env.SPORTSDATA_KEY, ...extraParams }
    : extraParams;
  return { headers, params };
}

function safeSnippet(x, max = 500) {
  try {
    const s = typeof x === "string" ? x : JSON.stringify(x);
    return s.length > max ? s.slice(0, max) + "..." : s;
  } catch {
    return String(x);
  }
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

router.use((req, res, next) => {
  console.log(`[API] ${req.method} ${req.originalUrl}`);
  next();
});

// -------------------------------------------
// helper: get all team-season stats for comp/season
// endpoint returns array of rounds, each with TeamSeasons[]
// -------------------------------------------
async function fetchUefaTeamSeasonStatsRaw(competitionId = 3, season = 2026) {
  const url = `${SOCCER_BASE}/TeamSeasonStats/${competitionId}/${season}`;
  const resp = await axios.get(url, authConfig());

  const rounds = Array.isArray(resp.data) ? resp.data : [];
  console.log(
    `[SportsDataIO] TeamSeasonStats competition=${competitionId} season=${season} -> ${rounds.length} rounds`
  );
  if (rounds.length) {
    console.log(`[SportsDataIO] TeamSeasonStats sample round: ${safeSnippet(rounds[0])}`);
  }

  return rounds;
}

function flattenTeamSeasons(rounds) {
  const out = [];

  for (const round of rounds) {
    const roundName = round?.Name || null;
    const items = Array.isArray(round?.TeamSeasons) ? round.TeamSeasons : [];

    for (const t of items) {
      out.push({
        ...t,
        __roundName: roundName,
      });
    }
  }

  return out;
}

// -------------------------------------------
// GET /uefa-team/stats/:teamId?season=2026&competitionId=3
// -------------------------------------------
router.get("/stats/:teamId", async (req, res) => {
  try {
    if (!apiKey()) {
      return res.status(500).json({ error: "SPORTSDATA_KEY is missing in .env" });
    }

    const teamId = Number(req.params.teamId);
    const season = Number(req.query.season || 2026);
    const competitionId = Number(req.query.competitionId || 3);

    if (!teamId) {
      return res.status(400).json({ error: "teamId is required" });
    }

    const rounds = await fetchUefaTeamSeasonStatsRaw(competitionId, season);
    const teamSeasons = flattenTeamSeasons(rounds);

    const found = teamSeasons.find((t) => Number(t.TeamId) === teamId);

    if (!found) {
      return res.status(404).json({ error: "No UEFA team stats found for this team" });
    }

    const normalized = {
      teamId: found.TeamId,
      name: found.Name || found.Team || "Team",
      season: found.Season,
      roundId: found.RoundId,
      roundName: found.__roundName,
      stats: {
        games: found.Games ?? 0,
        goals: found.Goals ?? 0,
        assists: found.Assists ?? 0,
        shots: found.Shots ?? 0,
        shotsOnGoal: found.ShotsOnGoal ?? 0,
        yellowCards: found.YellowCards ?? 0,
        redCards: found.RedCards ?? 0,
        tackles: found.Tackles ?? 0,
        possession: found.Possession ?? 0,
        passes: found.Passes ?? 0,
        passesCompleted: found.PassesCompleted ?? 0,
        fouls: found.Fouls ?? 0,
        fouled: found.Fouled ?? 0,
        cornersWon: found.CornersWon ?? 0,
        interceptions: found.Interceptions ?? 0,
        goalkeeperSaves: found.GoalkeeperSaves ?? 0,
        goalkeeperGoalsAgainst: found.GoalkeeperGoalsAgainst ?? 0,
        goalkeeperCleanSheets: found.GoalkeeperCleanSheets ?? 0,
        goalkeeperWins: found.GoalkeeperWins ?? 0,
        score: found.Score ?? 0,
        opponentScore: found.OpponentScore ?? 0,
        fantasyPoints: found.FantasyPoints ?? 0,
        minutes: found.Minutes ?? 0,
      },
    };

    console.log(`[API] UEFA team stats -> ${safeSnippet(normalized)}`);
    return res.json({ response: normalized });
  } catch (err) {
    logAxiosError("uefa-team/stats error:", err);
    return res.status(500).json({ error: "Failed to fetch UEFA team stats" });
  }
});

// -------------------------------------------
// GET /uefa-team/players/:teamId?competitionId=3
// -------------------------------------------
router.get("/players/:teamId", async (req, res) => {
  try {
    if (!apiKey()) {
      return res.status(500).json({ error: "SPORTSDATA_KEY is missing in .env" });
    }

    const teamId = Number(req.params.teamId);
    const competitionId = Number(req.query.competitionId || 3);

    if (!teamId) {
      return res.status(400).json({ error: "teamId is required" });
    }

    const url = `${SOCCER_BASE}/PlayersByTeamBasic/${competitionId}/${teamId}`;
    const resp = await axios.get(url, authConfig());

    const playersRaw = Array.isArray(resp.data) ? resp.data : [];
    console.log(`[SportsDataIO] PlayersByTeamBasic team=${teamId} -> ${playersRaw.length}`);
    if (playersRaw.length) {
      console.log(`[SportsDataIO] player sample -> ${safeSnippet(playersRaw[0])}`);
    }

    const players = playersRaw.map((p) => ({
      playerId: p.PlayerId,
      firstName: p.FirstName || "",
      lastName: p.LastName || "",
      commonName: p.CommonName || "",
      shortName: p.ShortName || "",
      position: p.Position || "-",
      positionCategory: p.PositionCategory || "-",
      jersey: p.Jersey ?? "-",
      foot: p.Foot || "-",
      height: p.Height ?? null,
      weight: p.Weight ?? null,
      nationality: p.Nationality || "-",
      birthDate: p.BirthDate || null,
    }));

    console.log(`[API] UEFA team players -> ${players.length}`);
    return res.json({ response: players });
  } catch (err) {
    logAxiosError("uefa-team/players error:", err);
    return res.status(500).json({ error: "Failed to fetch UEFA team players" });
  }
});

module.exports = router;