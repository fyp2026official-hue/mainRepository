function normStatus(rawStatus) {
  const s = String(rawStatus || "").trim().toLowerCase();

  if (s.includes("final") || s.startsWith("f/")) return "finished";
  if (s.includes("inprogress") || s.includes("in progress") || s.includes("live")) return "live";
  if (
    s.includes("scheduled") ||
    s.includes("pregame") ||
    s.includes("pre-game") ||
    s.includes("pre game") ||
    s === ""
  ) {
    return "scheduled";
  }

  return "unknown";
}

function normalizeNbaFixture(game) {
  return {
    source: "sportsdata",
    sport: "basketball",
    league: "NBA",
    gameId: String(game.GameID ?? ""),
    homeTeam: game.HomeTeam || "",
    awayTeam: game.AwayTeam || "",
    startTime: game.DateTimeUTC || game.DateTime || game.Day || null,
    status: normStatus(game.Status),
    rawStatus: game.Status || "",
    homeScore: game.HomeTeamScore ?? null,
    awayScore: game.AwayTeamScore ?? null,
  };
}

module.exports = {
  normalizeNbaFixture,
};