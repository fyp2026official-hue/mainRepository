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

router.use((req, res, next) => {
  console.log(`[API] ${req.method} ${req.originalUrl}`);
  next();
});

function logAxiosError(prefix, err) {
  const status = err?.response?.status;
  const data = err?.response?.data;
  if (status) {
    console.error(`${prefix} HTTP ${status} -> ${safeSnippet(data)}`);
  } else {
    console.error(`${prefix} -> ${err?.message || err}`);
  }
}

async function fetchUefaSchedule(competitionId = 3, season = 2026) {
  const url = `${SOCCER_BASE}/Schedule/${competitionId}/${season}`;
  const resp = await axios.get(url, authConfig());

  const rounds = Array.isArray(resp.data) ? resp.data : [];

  console.log(
    `[SportsDataIO] UEFA Schedule competition=${competitionId} season=${season} -> ${rounds.length} rounds`
  );
  if (rounds.length) {
    console.log(`[SportsDataIO] UEFA round sample: ${safeSnippet(rounds[0])}`);
  }

  return rounds;
}

function flattenGames(rounds) {
  const out = [];

  for (const round of rounds) {
    const roundName = round?.Name || null;
    const games = Array.isArray(round?.Games) ? round.Games : [];

    for (const g of games) {
      out.push({
        ...g,
        __roundName: roundName,
      });
    }
  }

  return out;
}

function sameDate(dateTimeStr, yyyyMmDd) {
  if (!dateTimeStr || !yyyyMmDd) return false;
  return String(dateTimeStr).slice(0, 10) === yyyyMmDd;
}

function normalizeSoccerStatus(status) {
  const s = String(status || "").toLowerCase();

  if (s.includes("final")) return "FT";
  if (s.includes("live") || s.includes("in progress") || s.includes("inprogress")) return "LIVE";
  if (s.includes("postponed")) return "PST";
  if (s.includes("canceled") || s.includes("cancelled")) return "CANC";
  return "NS";
}

function toFlutterUefaFixture(game) {
  const dateVal = game.DateTime ?? game.Day ?? null;

  return {
    fixture: {
      date: dateVal,
      status: {
        short: normalizeSoccerStatus(game.Status),
        elapsed: null,
      },
    },
    teams: {
      home: {
        name: game.HomeTeamName || game.HomeTeamKey || "Home",
        logo: null, // add logo source later if you have one
      },
      away: {
        name: game.AwayTeamName || game.AwayTeamKey || "Away",
        logo: null,
      },
    },
    goals: {
      home: game.HomeTeamScore ?? null,
      away: game.AwayTeamScore ?? null,
    },
    league: {
      round: game.__roundName || null,
    },
    extra: {
      homeFormation: game.HomeTeamFormation ?? null,
      awayFormation: game.AwayTeamFormation ?? null,
      venueId: game.VenueId ?? null,
      attendance: game.Attendance ?? null,
      isClosed: game.IsClosed ?? null,
    },
  };
}

// GET /default
router.get("/default", async (req, res) => {
  try {
    if (!apiKey()) {
      return res.status(500).json({ error: "SPORTSDATA_KEY is missing in .env" });
    }

    const competitionId = Number(req.query.competitionId || 3);
    const season = Number(req.query.season || 2026);

    const rounds = await fetchUefaSchedule(competitionId, season);
    const games = flattenGames(rounds);

    const now = new Date();

    const live = games
      .filter((g) => {
        const s = String(g.Status || "").toLowerCase();
        return s.includes("live") || s.includes("in progress") || s.includes("inprogress");
      })
      .map(toFlutterUefaFixture);

    const upcoming = games
      .filter((g) => {
        const dt = g.DateTime ? new Date(g.DateTime) : null;
        if (!dt) return false;

        const s = String(g.Status || "").toLowerCase();
        const isScheduled =
          s.includes("scheduled") ||
          s.includes("not started") ||
          s === "";

        return isScheduled && dt >= now;
      })
      .sort((a, b) => new Date(a.fixture.date) - new Date(b.fixture.date))
      .slice(0, 10);

    const out = {
      response: [...live, ...upcoming],
    };

    console.log(`[API] GET /uefa-fixtures/default -> ${out.response.length} fixtures`);
    console.log(`[API] sample fixture -> ${safeSnippet(out.response[0] || null)}`);

    return res.json(out);
  } catch (err) {
    logAxiosError("uefa-fixtures/default error:", err);
    return res.status(500).json({ error: "Failed to fetch UEFA fixtures default" });
  }
});

// GET /completed
router.get("/completed", async (req, res) => {
  try {
    if (!apiKey()) {
      return res.status(500).json({ error: "SPORTSDATA_KEY is missing in .env" });
    }

    const competitionId = Number(req.query.competitionId || 3);
    const season = Number(req.query.season || 2026);

    const rounds = await fetchUefaSchedule(competitionId, season);
    const games = flattenGames(rounds);

    const completed = games
      .filter((g) => String(g.Status || "").toLowerCase().includes("final"))
      .map(toFlutterUefaFixture)
      .sort((a, b) => new Date(b.fixture.date) - new Date(a.fixture.date))
      .slice(0, 20);

    const out = { response: completed };

    console.log(`[API] GET /uefa-fixtures/completed -> ${out.response.length} fixtures`);
    console.log(`[API] sample fixture -> ${safeSnippet(out.response[0] || null)}`);

    return res.json(out);
  } catch (err) {
    logAxiosError("uefa-fixtures/completed error:", err);
    return res.status(500).json({ error: "Failed to fetch completed UEFA fixtures" });
  }
});

// GET /by-date?date=YYYY-MM-DD
router.get("/by-date", async (req, res) => {
  try {
    const { date } = req.query;

    if (!date) {
      return res.status(400).json({ error: "date is required (YYYY-MM-DD)" });
    }

    if (!apiKey()) {
      return res.status(500).json({ error: "SPORTSDATA_KEY is missing in .env" });
    }

    const competitionId = Number(req.query.competitionId || 3);
    const season = Number(req.query.season || 2026);

    const rounds = await fetchUefaSchedule(competitionId, season);
    const games = flattenGames(rounds);

    const list = games
      .filter((g) => sameDate(g.DateTime ?? g.Day, date))
      .map(toFlutterUefaFixture)
      .sort((a, b) => new Date(a.fixture.date) - new Date(b.fixture.date));

    const out = { response: list };

    console.log(
      `[API] GET /uefa-fixtures/by-date?date=${date}&competitionId=${competitionId}&season=${season} -> ${out.response.length} fixtures`
    );
    console.log(`[API] sample fixture -> ${safeSnippet(out.response[0] || null)}`);

    return res.json(out);
  } catch (err) {
    logAxiosError("uefa-fixtures/by-date error:", err);
    return res.status(500).json({ error: "Failed to fetch UEFA fixtures by date" });
  }
});

module.exports = router;