const cron = require("node-cron");
const NotificationLog = require("../models/NotificationLog");
const { sendToAllUsers } = require("../services/notificationSender");
const { getNbaGamesByDate } = require("../services/nbaService");
const { normalizeNbaFixture } = require("../utils/normalizeFixture");

function fmtDate(d) {
  const yyyy = d.getFullYear();
  const mm = String(d.getMonth() + 1).padStart(2, "0");
  const dd = String(d.getDate()).padStart(2, "0");
  return `${yyyy}-${mm}-${dd}`;
}

async function runMatchStartCheck() {
  try {
    const today = new Date();
    const dateStr = fmtDate(today);

    console.log(`[MATCH START] Checking NBA games for ${dateStr}`);

    const rawGames = await getNbaGamesByDate(dateStr);
    const games = rawGames.map(normalizeNbaFixture);
    console.log(
  "[MATCH CHECK] normalized games:",
  JSON.stringify(
    games.map((g) => ({
      gameId: g.gameId,
      homeTeam: g.homeTeam,
      awayTeam: g.awayTeam,
      rawStatus: g.rawStatus,
      status: g.status,
      homeScore: g.homeScore,
      awayScore: g.awayScore,
      startTime: g.startTime,
    })),
    null,
    2
  )
);

    const liveGames = games.filter((g) => g.status === "live");

    console.log(`[MATCH START] Found ${liveGames.length} live game(s)`);

    for (const game of liveGames) {
      if (!game.gameId) continue;

      const alreadySent = await NotificationLog.findOne({
        eventType: "match_start",
        itemId: game.gameId,
      });

      if (alreadySent) {
        console.log(`[MATCH START] Skip already sent: ${game.gameId}`);
        continue;
      }

      const title = "Match Started";
      const body = `${game.homeTeam} vs ${game.awayTeam} has started`;

      const result = await sendToAllUsers({
        title,
        body,
        data: {
          type: "match_start",
          sport: game.sport,
          league: game.league,
          gameId: game.gameId,
          homeTeam: game.homeTeam,
          awayTeam: game.awayTeam,
        },
      });

      console.log(
        `[MATCH START] Sent for game ${game.gameId}:`,
        result
      );

      await NotificationLog.create({
        eventType: "match_start",
        itemId: game.gameId,
        league: game.league,
        sport: game.sport,
        meta: {
          homeTeam: game.homeTeam,
          awayTeam: game.awayTeam,
          startTime: game.startTime,
        },
      });
    }
  } catch (err) {
    console.error("[MATCH START] Error:", err?.message || err);
  }
}

function startMatchStartNotifier() {
  console.log("[MATCH START] Cron started: every 5 minutes");

  cron.schedule("*/5 * * * *", async () => {
    await runMatchStartCheck();
  });
}

module.exports = {
  startMatchStartNotifier,
  runMatchStartCheck,
};