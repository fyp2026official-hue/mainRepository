const cron = require("node-cron");
const axios = require("axios");
const NotificationLog = require("../models/NotificationLog");
const { sendToAllUsers } = require("../services/notificationSender");

const NEWS_BASE = "https://api.sportsdata.io/v3/nba/news-rotoballer/json";

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

// Convert YYYY-MM-DD -> YYYY-MMM-DD
function toSportsDataDate(ymd) {
  const [yyyy, mm, dd] = String(ymd || "").split("-");
  if (!yyyy || !mm || !dd) return null;

  const monthNames = [
    "JAN", "FEB", "MAR", "APR", "MAY", "JUN",
    "JUL", "AUG", "SEP", "OCT", "NOV", "DEC",
  ];

  const m = Number(mm);
  if (!m || m < 1 || m > 12) return null;

  return `${yyyy}-${monthNames[m - 1]}-${dd}`;
}

function fmtDate(d) {
  const yyyy = d.getFullYear();
  const mm = String(d.getMonth() + 1).padStart(2, "0");
  const dd = String(d.getDate()).padStart(2, "0");
  return `${yyyy}-${mm}-${dd}`;
}

async function getNbaNewsByDate(dateStr) {
  if (!apiKey()) {
    throw new Error("SPORTSDATA_KEY is missing in .env");
  }

  const sportsDate = toSportsDataDate(dateStr);
  if (!sportsDate) {
    throw new Error(`Invalid date for news: ${dateStr}`);
  }

  const resp = await axios.get(
    `${NEWS_BASE}/RotoBallerPremiumNewsByDate/${sportsDate}`,
    authConfig()
  );

  return Array.isArray(resp.data) ? resp.data : [];
}

function normalizeNewsItem(item) {
  return {
    source: "sportsdata",
    sport: "basketball",
    league: "NBA",
    articleId: String(
      item.NewsID ??
      item.NewsId ??
      item.ID ??
      item.Id ??
      item.Url ??
      item.URL ??
      item.Title ??
      ""
    ),
    title: item.Title || "NBA News",
    body:
      item.Content ||
      item.Description ||
      item.Summary ||
      "New NBA news available",
    url: item.Url || item.URL || "",
    imageUrl: item.ImageUrl || item.ImageURL || item.Image || "",
    publishedAt:
      item.Updated ||
      item.TimeAgo ||
      item.Published ||
      item.Created ||
      null,
  };
}

function shortText(text, max = 140) {
  const s = String(text || "").replace(/\s+/g, " ").trim();
  if (!s) return "New NBA news available";
  return s.length > max ? `${s.slice(0, max)}...` : s;
}

async function runNewsCheck() {
  try {
    const today = new Date();
    const dateStr = fmtDate(today);

    console.log(`[NEWS] Checking NBA news for ${dateStr}`);

    const rawNews = await getNbaNewsByDate(dateStr);
    const newsItems = rawNews.map(normalizeNewsItem);

    console.log(`[NEWS] Found ${newsItems.length} news item(s)`);

    for (const article of newsItems) {
      if (!article.articleId) continue;

      const alreadySent = await NotificationLog.findOne({
        eventType: "news",
        itemId: article.articleId,
      });

      if (alreadySent) {
        console.log(`[NEWS] Skip already sent: ${article.articleId}`);
        continue;
      }

      const title = article.title || "NBA News";
      const body = shortText(article.body, 120);

      const result = await sendToAllUsers({
        title,
        body,
        data: {
          type: "news",
          sport: article.sport,
          league: article.league,
          articleId: article.articleId,
          url: article.url,
          imageUrl: article.imageUrl,
        },
      });

      console.log(`[NEWS] Sent for article ${article.articleId}:`, result);

      await NotificationLog.create({
        eventType: "news",
        itemId: article.articleId,
        league: article.league,
        sport: article.sport,
        meta: {
          title: article.title,
          url: article.url,
          imageUrl: article.imageUrl,
          publishedAt: article.publishedAt,
        },
      });
    }
  } catch (err) {
    console.error("[NEWS] Error:", err?.message || err);
  }
}

function startNewsNotifier() {
  console.log("[NEWS] Cron started: every 10 minutes");

  cron.schedule("*/10 * * * *", async () => {
    await runNewsCheck();
  });
}

module.exports = {
  startNewsNotifier,
  runNewsCheck,
};