require("dotenv").config();
const express = require("express");
const cors = require("cors");
const connectDB = require("./config/db");

const standingsRoute = require("./routes/standings");
const standingUEFA = require("./routes/standing_uefa");
const userRoutes = require("./routes/userRoutes");
const fixturesRoutes = require("./routes/fixtures");
const teamRoutes = require("./routes/team");
const newsRouter = require("./routes/news");
const nbaRoutes = require("./routes/nba_match_details");
const tournaments = require("./routes/tournaments");
const uefaFixturesRouter = require("./routes/uefa_fixtures");
const uefaTeamRouter = require("./routes/uefa_team");
const { startMatchStartNotifier } = require("./jobs/matchStartNotifier");
const { startMatchEndNotifier } = require("./jobs/matchEndNotifier");
const { startNewsNotifier } = require("./jobs/newsNotifier");

const app = express();

app.use(cors());
app.use(express.json({ limit: "2mb" }));

app.use("/fixtures", fixturesRoutes);
app.use("/uefa-fixtures", uefaFixturesRouter);

app.get("/", (req, res) => res.send("Backend running (NBA - SportsDataIO only)"));

// users/auth
app.use("/api/users", userRoutes);
app.use("/api/tournaments", tournaments);

// NBA
app.use("/standings", standingsRoute);
app.use("/team", teamRoutes);
app.use("/news", newsRouter);
app.use("/api/nba", nbaRoutes);

// UEFA
app.use("/uefa-standings", standingUEFA);
app.use("/uefa-team", uefaTeamRouter);

const PORT = process.env.PORT || 5000;

connectDB()
  .then(() => {
    console.log("SPORTSDATA_KEY loaded?", Boolean(process.env.SPORTSDATA_KEY));

    startMatchStartNotifier();
    startMatchEndNotifier();
    startNewsNotifier();

    app.listen(PORT, "0.0.0.0", () => {
      console.log(`Server running on port ${PORT}`);
    });
  })
  .catch((err) => {
    console.error("❌ DB connection error:", err);
    process.exit(1);
  });