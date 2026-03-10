const axios = require("axios");

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

async function getNbaGamesByDate(dateStr) {
  if (!apiKey()) {
    throw new Error("SPORTSDATA_KEY is missing in .env");
  }

  const resp = await axios.get(
    `${NBA_BASE}/GamesByDate/${dateStr}`,
    authConfig()
  );

  const games = Array.isArray(resp.data) ? resp.data : [];

  console.log(`[NBA API] GamesByDate ${dateStr} -> ${games.length} game(s)`);
  if (games.length > 0) {
    console.log("[NBA API] sample raw game:", JSON.stringify(games[0], null, 2));
  }

  return games;
}

module.exports = {
  getNbaGamesByDate,
};