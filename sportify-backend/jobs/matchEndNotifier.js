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

async function runMatchEndCheck() {
  try {
    const today = new Date();
    const dateStr = fmtDate(today);

    console.log(`[MATCH END] Checking NBA games for ${dateStr}`);

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

    const finishedGames = games.filter((g) => g.status === "finished");

    console.log(`[MATCH END] Found ${finishedGames.length} finished game(s)`);

    for (const game of finishedGames) {
      if (!game.gameId) continue;

      const alreadySent = await NotificationLog.findOne({
        eventType: "match_end",
        itemId: game.gameId,
      });

      if (alreadySent) {
        console.log(`[MATCH END] Skip already sent: ${game.gameId}`);
        continue;
      }

      const title = "Match Finished";
      const body = `${game.homeTeam} ${game.homeScore ?? 0} - ${game.awayScore ?? 0} ${game.awayTeam}`;

      const result = await sendToAllUsers({
        title,
        body,
        data: {
          type: "match_end",
          sport: game.sport,
          league: game.league,
          gameId: game.gameId,
          homeTeam: game.homeTeam,
          awayTeam: game.awayTeam,
          homeScore: game.homeScore ?? 0,
          awayScore: game.awayScore ?? 0,
        },
      });

      console.log(`[MATCH END] Sent for game ${game.gameId}:`, result);

      await NotificationLog.create({
        eventType: "match_end",
        itemId: game.gameId,
        league: game.league,
        sport: game.sport,
        meta: {
          homeTeam: game.homeTeam,
          awayTeam: game.awayTeam,
          homeScore: game.homeScore,
          awayScore: game.awayScore,
          startTime: game.startTime,
        },
      });
    }
  } catch (err) {
    console.error("[MATCH END] Error:", err?.message || err);
  }
}

function startMatchEndNotifier() {
  console.log("[MATCH END] Cron started: every 5 minutes");

  cron.schedule("*/5 * * * *", async () => {
    await runMatchEndCheck();
  });
}

module.exports = {
  startMatchEndNotifier,
  runMatchEndCheck,
};