import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_svg/flutter_svg.dart';

enum FixturesFilter { byDate }

class StandingsScreen extends StatefulWidget {
  const StandingsScreen({super.key});

  @override
  State<StandingsScreen> createState() => _StandingsScreenState();
}

class _StandingsScreenState extends State<StandingsScreen> {
  final String baseUrl = "http://192.168.10.9:5000";
  int _requestToken = 0;

  final List<Map<String, dynamic>> leagues = const [
    {
      "id": 12,
      "name": "NBA",
      "sport": "basketball",
      "standingsPath": "/standings",
      "supportsFixtures": true,
      "fixturesPath": "/fixtures/by-date",
    },
    {
      "id": 3,
      "name": "Champions League",
      "sport": "soccer",
      "standingsPath": "/uefa-standings",
      "supportsFixtures": true,
      "fixturesPath": "/uefa-fixtures/by-date",
      "competitionId": "3",
    },
  ];

  int? selectedLeagueId;
  String? selectedSport;
  int? season;

  bool loading = false;
  bool isExpanded = false;
  List standings = [];
  String? errorText;

  bool fixturesLoading = false;
  List fixtures = [];
  FixturesFilter fixturesFilter = FixturesFilter.byDate;
  DateTime? selectedDate;

  final Map<String, _MatchDetailsCache> _matchCache = {};

  String _fmtYmd(DateTime d) {
    String two(int n) => n.toString().padLeft(2, "0");
    return "${d.year}-${two(d.month)}-${two(d.day)}";
  }

  String _fmtPrettyDateTime(String? rawDate) {
    if (rawDate == null || rawDate.trim().isEmpty) return "-";
    final dt = DateTime.tryParse(rawDate);
    if (dt == null) return rawDate;

    final d = dt.toLocal();
    String two(int n) => n.toString().padLeft(2, "0");
    return "${two(d.day)}/${two(d.month)}/${d.year}  •  ${two(d.hour)}:${two(d.minute)}";
  }

  double _toDouble(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  Map<String, dynamic>? get _selectedLeague {
    if (selectedLeagueId == null) return null;
    try {
      return leagues.firstWhere((l) => l["id"] == selectedLeagueId);
    } catch (_) {
      return null;
    }
  }

  Uri _standingsUri() {
    final league = _selectedLeague ?? {};
    final path = (league["standingsPath"] ?? "/standings").toString();

    if ((league["sport"] ?? "") == "basketball") {
      return (season == null)
          ? Uri.parse("$baseUrl$path")
          : Uri.parse("$baseUrl$path?season=$season");
    }

    final compId = (league["competitionId"] ?? "3").toString();
    final seasonUsed = (season ?? 2026).toString();
    return Uri.parse("$baseUrl$path?competitionId=$compId&season=$seasonUsed");
  }

  Uri _fixturesByDateUri() {
    final league = _selectedLeague ?? {};
    final supportsFixtures = league["supportsFixtures"] == true;
    final path = (league["fixturesPath"] ?? "/fixtures/by-date").toString();
    final d = selectedDate ?? DateTime.now();

    if (!supportsFixtures) {
      return Uri.parse("$baseUrl$path?date=${_fmtYmd(d)}");
    }

    final sport = (league["sport"] ?? "").toString();

    if (sport == "soccer") {
      final compId = (league["competitionId"] ?? "3").toString();
      final seasonUsed = (season ?? 2026).toString();
      return Uri.parse(
        "$baseUrl$path?date=${_fmtYmd(d)}&competitionId=$compId&season=$seasonUsed",
      );
    }

    return Uri.parse("$baseUrl$path?date=${_fmtYmd(d)}");
  }

  Future<void> fetchStandings(int token) async {
    final league = _selectedLeague;
    if (league == null || selectedSport == null) return;

    setState(() {
      loading = true;
      errorText = null;
      isExpanded = false;
      standings = [];
    });

    try {
      final uri = _standingsUri();
      final response = await http.get(uri);

      if (!mounted || token != _requestToken) return;

      debugPrint("✅ $uri status: ${response.statusCode}");
      if (response.statusCode != 200) {
        throw Exception("HTTP ${response.statusCode}: ${response.body}");
      }

      final data = jsonDecode(response.body);

      final leagueObj = data["response"]?[0]?["league"];
      final rawStandings = leagueObj?["standings"];

      List parsed = [];
      if (rawStandings is List && rawStandings.isNotEmpty) {
        parsed = (rawStandings[0] is List)
            ? List.from(rawStandings[0])
            : List.from(rawStandings);
      }

      if ((league["sport"] ?? "") == "basketball") {
        double toPct(dynamic v) {
          if (v == null) return -1;
          if (v is num) return v.toDouble();
          final s = v.toString().trim().replaceAll('%', '');
          return double.tryParse(s) ?? -1;
        }

        parsed.sort((a, b) => toPct(b["rank"]).compareTo(toPct(a["rank"])));
        parsed = parsed.take(8).toList();
      } else {
        int toRank(dynamic v) => int.tryParse((v ?? "").toString()) ?? 999999;
        parsed.sort((a, b) => toRank(a["rank"]).compareTo(toRank(b["rank"])));
        parsed = parsed.take(24).toList();
      }

      if (!mounted || token != _requestToken) return;
      setState(() {
        standings = parsed;
        loading = false;
      });
    } catch (e) {
      if (!mounted || token != _requestToken) return;
      setState(() {
        loading = false;
        standings = [];
        errorText = e.toString();
      });
    }
  }

  Future<void> fetchFixturesByDate(int token) async {
    final league = _selectedLeague;
    if (league == null || selectedSport == null) return;
    if (league["supportsFixtures"] != true) return;

    setState(() {
      fixturesLoading = true;
      fixtures = [];
    });

    try {
      final uri = _fixturesByDateUri();
      final response = await http.get(uri);

      if (!mounted || token != _requestToken) return;

      debugPrint("✅ ${uri.toString()} status: ${response.statusCode}");
      debugPrint(
        "✅ fixtures body (first 250): ${response.body.length > 250 ? response.body.substring(0, 250) : response.body}",
      );

      if (response.statusCode != 200) {
        throw Exception("HTTP ${response.statusCode}: ${response.body}");
      }

      final data = jsonDecode(response.body);
      final list = (data["response"] is List) ? List.from(data["response"]) : [];

      debugPrint("✅ parsed fixtures count: ${list.length}");

      if (!mounted || token != _requestToken) return;
      setState(() {
        fixtures = list;
        fixturesLoading = false;
      });
    } catch (e) {
      debugPrint("❌ fetchFixturesByDate error: $e");
      if (!mounted || token != _requestToken) return;
      setState(() {
        fixtures = [];
        fixturesLoading = false;
      });
    }
  }

  Future<void> _pickDateAndFetch() async {
    final league = _selectedLeague;
    if (league == null || selectedSport == null) return;
    if (league["supportsFixtures"] != true) return;

    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? DateTime.now(),
      firstDate: DateTime(DateTime.now().year - 2),
      lastDate: DateTime(DateTime.now().year + 2),
    );

    if (picked == null) return;

    setState(() => selectedDate = picked);

    final newToken = ++_requestToken;
    await fetchFixturesByDate(newToken);
  }

  Widget _byDateFilterControl() {
    final label = selectedDate == null ? "Select Date" : "Date: ${_fmtYmd(selectedDate!)}";

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _pickDateAndFetch,
          icon: const Icon(Icons.calendar_today),
          label: Text(label),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ),
    );
  }

  Future<List> _fetchTeamPlayers(String teamIdentifier) async {
    final uri = Uri.parse("$baseUrl/team/players/$teamIdentifier");
    final res = await http.get(uri);

    debugPrint("✅ $uri status: ${res.statusCode}");
    debugPrint(
      "✅ players body (first 250): ${res.body.length > 250 ? res.body.substring(0, 250) : res.body}",
    );

    if (res.statusCode != 200) throw Exception(res.body);
    final data = jsonDecode(res.body);
    return (data["response"] is List) ? List.from(data["response"]) : [];
  }

  Future<Map<String, dynamic>?> _fetchTeamSeasonStats(String teamIdentifier, int seasonYear) async {
    final uri = Uri.parse("$baseUrl/team/stats/$teamIdentifier?season=$seasonYear");
    final res = await http.get(uri);

    debugPrint("✅ $uri status: ${res.statusCode}");
    debugPrint(
      "✅ stats body (first 250): ${res.body.length > 250 ? res.body.substring(0, 250) : res.body}",
    );

    if (res.statusCode != 200) throw Exception(res.body);
    final data = jsonDecode(res.body);
    return (data["response"] is Map) ? Map<String, dynamic>.from(data["response"]) : null;
  }

  Future<List> _fetchUefaTeamPlayers(int teamId, {int competitionId = 3}) async {
    final uri = Uri.parse("$baseUrl/uefa-team/players/$teamId?competitionId=$competitionId");
    final res = await http.get(uri);

    debugPrint("✅ $uri status: ${res.statusCode}");
    debugPrint(
      "✅ uefa players body (first 250): ${res.body.length > 250 ? res.body.substring(0, 250) : res.body}",
    );

    if (res.statusCode != 200) throw Exception(res.body);

    final data = jsonDecode(res.body);
    return (data["response"] is List) ? List.from(data["response"]) : [];
  }

  Future<Map<String, dynamic>?> _fetchUefaTeamStats(
    int teamId, {
    int seasonYear = 2026,
    int competitionId = 3,
  }) async {
    final uri = Uri.parse(
      "$baseUrl/uefa-team/stats/$teamId?season=$seasonYear&competitionId=$competitionId",
    );
    final res = await http.get(uri);

    debugPrint("✅ $uri status: ${res.statusCode}");
    debugPrint(
      "✅ uefa stats body (first 250): ${res.body.length > 250 ? res.body.substring(0, 250) : res.body}",
    );

    if (res.statusCode != 200) throw Exception(res.body);

    final data = jsonDecode(res.body);
    return (data["response"] is Map) ? Map<String, dynamic>.from(data["response"]) : null;
  }

  String _toNbaAbbrFromName(String name) {
    final n = name.trim().toLowerCase();
    const map = <String, String>{
      "new york knicks": "NY",
      "knicks": "NY",
      "san antonio spurs": "SA",
      "spurs": "SA",
      "los angeles lakers": "LAL",
      "lakers": "LAL",
      "golden state warriors": "GS",
      "warriors": "GS",
      "boston celtics": "BOS",
      "celtics": "BOS",
      "miami heat": "MIA",
      "heat": "MIA",
      "dallas mavericks": "DAL",
      "mavericks": "DAL",
      "denver nuggets": "DEN",
      "nuggets": "DEN",
      "phoenix suns": "PHX",
      "suns": "PHX",
      "milwaukee bucks": "MIL",
      "bucks": "MIL",
      "philadelphia 76ers": "PHI",
      "76ers": "PHI",
      "brooklyn nets": "BKN",
      "nets": "BKN",
      "chicago bulls": "CHI",
      "bulls": "CHI",
      "cleveland cavaliers": "CLE",
      "cavaliers": "CLE",
      "oklahoma city thunder": "OKC",
      "thunder": "OKC",
      "minnesota timberwolves": "MIN",
      "timberwolves": "MIN",
      "sacramento kings": "SAC",
      "kings": "SAC",
      "orlando magic": "ORL",
      "magic": "ORL",
      "toronto raptors": "TOR",
      "raptors": "TOR",
      "atlanta hawks": "ATL",
      "hawks": "ATL",
      "houston rockets": "HOU",
      "rockets": "HOU",
      "memphis grizzlies": "MEM",
      "grizzlies": "MEM",
      "new orleans pelicans": "NO",
      "pelicans": "NO",
      "washington wizards": "WAS",
      "wizards": "WAS",
      "utah jazz": "UTA",
      "jazz": "UTA",
      "portland trail blazers": "POR",
      "trail blazers": "POR",
      "blazers": "POR",
      "detroit pistons": "DET",
      "pistons": "DET",
      "indiana pacers": "IND",
      "pacers": "IND",
      "charlotte hornets": "CHA",
      "hornets": "CHA",
      "los angeles clippers": "LAC",
      "clippers": "LAC",
    };
    return map[n] ?? name;
  }

  String _matchKey(String dateYmd, String homeName, String awayName) {
    return "$dateYmd|${homeName.toLowerCase()}|${awayName.toLowerCase()}";
  }

  Future<_MatchDetailsCache> _fetchMatchDetails({
    required String dateYmd,
    required String homeName,
    required String awayName,
  }) async {
    final homeCode = _toNbaAbbrFromName(homeName);
    final awayCode = _toNbaAbbrFromName(awayName);

    final combinedUri = Uri.parse(
      "$baseUrl/api/nba/match-details?date=$dateYmd&home=$homeCode&away=$awayCode",
    );
    try {
      final res = await http.get(combinedUri);
      debugPrint("✅ $combinedUri status: ${res.statusCode}");
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final resp = (body["response"] is Map)
            ? Map<String, dynamic>.from(body["response"])
            : <String, dynamic>{};

        final h2h = (resp["h2h"] is Map) ? Map<String, dynamic>.from(resp["h2h"]) : null;
        final lineups =
            (resp["lineups"] is Map) ? Map<String, dynamic>.from(resp["lineups"]) : null;

        return _MatchDetailsCache(
          dateYmd: dateYmd,
          homeName: homeName,
          awayName: awayName,
          homeCode: homeCode,
          awayCode: awayCode,
          h2h: h2h,
          lineups: lineups,
        );
      }
    } catch (_) {}

    final h2hUri = Uri.parse("$baseUrl/api/nba/h2h?home=$homeCode&away=$awayCode");
    final lineupsUri = Uri.parse(
      "$baseUrl/api/nba/starting-lineups?date=$dateYmd&home=$homeCode&away=$awayCode",
    );

    final results = await Future.wait([http.get(h2hUri), http.get(lineupsUri)]);

    Map<String, dynamic>? h2h;
    Map<String, dynamic>? lineups;

    if (results[0].statusCode == 200) {
      final b = jsonDecode(results[0].body);
      h2h = (b["response"] is Map) ? Map<String, dynamic>.from(b["response"]) : null;
    }

    if (results[1].statusCode == 200) {
      final b = jsonDecode(results[1].body);
      final resp =
          (b["response"] is Map) ? Map<String, dynamic>.from(b["response"]) : <String, dynamic>{};
      final game = (resp["game"] is Map) ? Map<String, dynamic>.from(resp["game"]) : null;
      lineups = game;
    }

    return _MatchDetailsCache(
      dateYmd: dateYmd,
      homeName: homeName,
      awayName: awayName,
      homeCode: homeCode,
      awayCode: awayCode,
      h2h: h2h,
      lineups: lineups,
    );
  }

  Future<void> _openMatchPopup(dynamic fixtureItem) async {
    final homeName = fixtureItem["teams"]?["home"]?["name"]?.toString() ?? "HOME";
    final awayName = fixtureItem["teams"]?["away"]?["name"]?.toString() ?? "AWAY";
    final homeLogo = fixtureItem["teams"]?["home"]?["logo"]?.toString();
    final awayLogo = fixtureItem["teams"]?["away"]?["logo"]?.toString();

    final dateYmd = _fmtYmd(selectedDate ?? DateTime.now());
    final key = _matchKey(dateYmd, homeName, awayName);

    showDialog(
      context: context,
      builder: (ctx) {
        final screenW = MediaQuery.of(ctx).size.width;
        final screenH = MediaQuery.of(ctx).size.height;

        final dialogW = math.min(screenW * 0.92, 980.0);
        final dialogH = screenH * 0.84;

        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: SizedBox(
            width: dialogW,
            height: dialogH,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Column(
                children: [
                  Row(
                    children: [
                      SizedBox(width: 30, height: 30, child: _teamLogo(homeLogo, size: 30)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          "$homeName  vs  $awayName",
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Divider(height: 1),
                  const SizedBox(height: 10),
                  Expanded(
                    child: FutureBuilder<_MatchDetailsCache>(
                      future: () async {
                        if (_matchCache.containsKey(key)) return _matchCache[key]!;
                        final d = await _fetchMatchDetails(
                          dateYmd: dateYmd,
                          homeName: homeName,
                          awayName: awayName,
                        );
                        _matchCache[key] = d;
                        return d;
                      }(),
                      builder: (context, snap) {
                        if (snap.connectionState != ConnectionState.done) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        if (snap.hasError) {
                          return Center(
                            child: Text(
                              "Failed to load match details.\n${snap.error}",
                              textAlign: TextAlign.center,
                            ),
                          );
                        }

                        final details = snap.data!;
                        final h2h = details.h2h;
                        final lineups = details.lineups;

                        Widget pill(String text) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.black12,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600)),
                          );
                        }

                        Widget h2hBlock() {
                          if (h2h == null) return const Text("Head-to-Head: Not available");

                          final homeWins = h2h["homeWins"]?.toString() ?? "-";
                          final awayWins = h2h["awayWins"]?.toString() ?? "-";
                          final ties = h2h["ties"]?.toString() ?? "0";
                          final total = h2h["totalGames"]?.toString() ?? "-";

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Head-to-Head (${details.homeCode} vs ${details.awayCode})",
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 10),
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: [
                                    pill("${details.homeCode} Wins: $homeWins"),
                                    const SizedBox(width: 8),
                                    pill("${details.awayCode} Wins: $awayWins"),
                                    const SizedBox(width: 8),
                                    pill("Ties: $ties"),
                                    const SizedBox(width: 8),
                                    pill("Total: $total"),
                                  ],
                                ),
                              ),
                            ],
                          );
                        }

                        List<Map<String, dynamic>> safeList(dynamic v) {
                          if (v is List) {
                            return v
                                .whereType<Map>()
                                .map((e) => Map<String, dynamic>.from(e))
                                .toList();
                          }
                          return [];
                        }

                        final homeStarters = safeList(lineups?["homeStarters"]);
                        final awayStarters = safeList(lineups?["awayStarters"]);

                        String playerName(Map<String, dynamic> p) {
                          final fn = p["firstName"]?.toString() ?? "";
                          final ln = p["lastName"]?.toString() ?? "";
                          final name = ("$fn $ln").trim();
                          return name.isEmpty ? "Player" : name;
                        }

                        String playerPos(Map<String, dynamic> p) {
                          return p["position"]?.toString() ?? "-";
                        }

                        Widget sectionTitle(String t, String? logo) {
                          return Row(
                            children: [
                              SizedBox(width: 22, height: 22, child: _teamLogo(logo, size: 22)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  t,
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          );
                        }

                        Widget rowPlayer(Map<String, dynamic> p) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(playerName(p), overflow: TextOverflow.ellipsis),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  playerPos(p),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        Widget startersOneColumn() {
                          if (homeStarters.isEmpty && awayStarters.isEmpty) {
                            return const Text("Starting 5: Not available");
                          }

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("Starting 5",
                                  style: TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 10),
                              sectionTitle(homeName, homeLogo),
                              const SizedBox(height: 8),
                              ...homeStarters.map(rowPlayer),
                              const SizedBox(height: 10),
                              const Divider(),
                              sectionTitle(awayName, awayLogo),
                              const SizedBox(height: 8),
                              ...awayStarters.map(rowPlayer),
                            ],
                          );
                        }

                        return SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              h2hBlock(),
                              const SizedBox(height: 12),
                              const Divider(),
                              const SizedBox(height: 8),
                              startersOneColumn(),
                              const SizedBox(height: 12),
                              if (lineups == null)
                                const Text(
                                  "Note: Starting lineups not found for this game/date.",
                                  style: TextStyle(color: Colors.black54),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Divider(height: 1),
                  const SizedBox(height: 10),
                  Center(
                    child: SizedBox(
                      width: 180,
                      height: 44,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text("Close"),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _radarStatsChart(Map<String, dynamic> stats) {
    final opp = (stats["OpponentStat"] is Map)
        ? Map<String, dynamic>.from(stats["OpponentStat"])
        : null;

    final pf = _toDouble(stats["Points"]);
    final pa = _toDouble(opp?["Points"]);
    final ast = _toDouble(stats["Assists"]);
    final reb = _toDouble(stats["Rebounds"]);
    final fg = _toDouble(stats["FieldGoalsPercentage"]);
    final tp = _toDouble(stats["ThreePointersPercentage"]);
    final tov = _toDouble(stats["Turnovers"]);

    double norm(double v, double cap) => cap <= 0 ? 0 : (v / cap).clamp(0.0, 1.0);

    final metrics = <_RadarMetric>[
      _RadarMetric("PF", norm(pf, 11000)),
      _RadarMetric("DEF", 1.0 - norm(pa, 11000)),
      _RadarMetric("AST", norm(ast, 3000)),
      _RadarMetric("REB", norm(reb, 4500)),
      _RadarMetric("SHT", norm((fg + tp) / 2.0, 60)),
      _RadarMetric("TOV", 1.0 - norm(tov, 1600)),
    ];

    return SizedBox(
      height: 240,
      child: CustomPaint(
        painter: _RadarPainter(metrics: metrics),
        child: const SizedBox.expand(),
      ),
    );
  }

  Widget _ppgBarChart(Map<String, dynamic> stats) {
    final opp = (stats["OpponentStat"] is Map)
        ? Map<String, dynamic>.from(stats["OpponentStat"])
        : null;
    final pf = _toDouble(stats["Points"]);
    final pa = _toDouble(opp?["Points"]);

    final maxV = math.max(pf, pa).clamp(1, double.infinity);

    Widget barRow(String label, double value) {
      final frac = (value / maxV).clamp(0.0, 1.0);
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          children: [
            SizedBox(
              width: 90,
              child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: frac,
                  minHeight: 14,
                  backgroundColor: Colors.black12,
                ),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 80,
              child: Text(value.toStringAsFixed(0), textAlign: TextAlign.right),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        barRow("Points For", pf),
        barRow("Points Against", pa),
      ],
    );
  }

  Widget _soccerRadarChart(Map<String, dynamic> stats) {
    final goals = _toDouble(stats["goals"]);
    final assists = _toDouble(stats["assists"]);
    final shotsOnGoal = _toDouble(stats["shotsOnGoal"]);
    final passesCompleted = _toDouble(stats["passesCompleted"]);
    final tackles = _toDouble(stats["tackles"]);
    final interceptions = _toDouble(stats["interceptions"]);
    final cornersWon = _toDouble(stats["cornersWon"]);
    final saves = _toDouble(stats["goalkeeperSaves"]);

    double norm(double v, double cap) => cap <= 0 ? 0 : (v / cap).clamp(0.0, 1.0);

    final metrics = <_RadarMetric>[
      _RadarMetric("GOALS", norm(goals, 30)),
      _RadarMetric("AST", norm(assists, 25)),
      _RadarMetric("SOG", norm(shotsOnGoal, 40)),
      _RadarMetric("PASS", norm(passesCompleted, 5000)),
      _RadarMetric("TACK", norm(tackles, 120)),
      _RadarMetric("INT", norm(interceptions, 120)),
      _RadarMetric("CORN", norm(cornersWon, 80)),
      _RadarMetric("SAV", norm(saves, 40)),
    ];

    return SizedBox(
      height: 260,
      child: CustomPaint(
        painter: _RadarPainter(metrics: metrics),
        child: const SizedBox.expand(),
      ),
    );
  }

  Widget _soccerGoalsBarChart(Map<String, dynamic> stats) {
    final goalsFor = _toDouble(stats["goals"]);
    final goalsAgainst = _toDouble(stats["goalkeeperGoalsAgainst"]);
    final maxV = math.max(goalsFor, goalsAgainst).clamp(1, double.infinity);

    Widget barRow(String label, double value) {
      final frac = (value / maxV).clamp(0.0, 1.0);
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          children: [
            SizedBox(
              width: 110,
              child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: frac,
                  minHeight: 14,
                  backgroundColor: Colors.black12,
                ),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 70,
              child: Text(value.toStringAsFixed(1), textAlign: TextAlign.right),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        barRow("Goals For", goalsFor),
        barRow("Goals Against", goalsAgainst),
      ],
    );
  }

  Widget _soccerDisciplineBarChart(Map<String, dynamic> stats) {
    final yellow = _toDouble(stats["yellowCards"]);
    final red = _toDouble(stats["redCards"]);
    final fouls = _toDouble(stats["fouls"]);
    final corners = _toDouble(stats["cornersWon"]);

    final maxV = [yellow, red, fouls, corners].reduce(math.max).clamp(1, double.infinity);

    Widget barRow(String label, double value) {
      final frac = (value / maxV).clamp(0.0, 1.0);
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          children: [
            SizedBox(
              width: 110,
              child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: frac,
                  minHeight: 14,
                  backgroundColor: Colors.black12,
                ),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 70,
              child: Text(value.toStringAsFixed(1), textAlign: TextAlign.right),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        barRow("Yellow Cards", yellow),
        barRow("Red Cards", red),
        barRow("Fouls", fouls),
        barRow("Corners", corners),
      ],
    );
  }

  Widget _soccerAttackBarChart(Map<String, dynamic> stats) {
    final shots = _toDouble(stats["shots"]);
    final shotsOnGoal = _toDouble(stats["shotsOnGoal"]);
    final assists = _toDouble(stats["assists"]);
    final passes = _toDouble(stats["passesCompleted"]);

    final maxV = [shots, shotsOnGoal, assists, passes].reduce(math.max).clamp(1, double.infinity);

    Widget barRow(String label, double value) {
      final frac = (value / maxV).clamp(0.0, 1.0);
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          children: [
            SizedBox(
              width: 110,
              child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: frac,
                  minHeight: 14,
                  backgroundColor: Colors.black12,
                ),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 70,
              child: Text(value.toStringAsFixed(1), textAlign: TextAlign.right),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        barRow("Shots", shots),
        barRow("Shots On Goal", shotsOnGoal),
        barRow("Assists", assists),
        barRow("Passes", passes),
      ],
    );
  }

  Future<void> _openTeamPopup(dynamic teamItem) async {
    final teamObj = teamItem["team"];
    final teamName = teamObj?["name"]?.toString() ?? teamItem["name"]?.toString() ?? "Team";
    final teamLogo = (teamObj?["logo"] ?? teamItem["logo"])?.toString();

    final teamIdentifier = teamName;
    final seasonYear = DateTime.now().year;

    showDialog(
      context: context,
      builder: (ctx) {
        final screenW = MediaQuery.of(ctx).size.width;
        final screenH = MediaQuery.of(ctx).size.height;

        final dialogW = math.min(screenW * 0.90, 950.0);
        final dialogH = screenH * 0.82;

        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: SizedBox(
            width: dialogW,
            height: dialogH,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Column(
                children: [
                  Row(
                    children: [
                      SizedBox(width: 28, height: 28, child: _teamLogo(teamLogo, size: 28)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          teamName,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 10),
                  Expanded(
                    child: FutureBuilder(
                      future: Future.wait([
                        _fetchTeamPlayers(teamIdentifier),
                        _fetchTeamSeasonStats(teamIdentifier, seasonYear),
                      ]),
                      builder: (context, snap) {
                        if (snap.connectionState != ConnectionState.done) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        if (snap.hasError) {
                          return Center(
                            child: Text("Failed to load.\n${snap.error}",
                                textAlign: TextAlign.center),
                          );
                        }

                        final results = snap.data as List;
                        final players = results[0] as List;
                        final stats = results[1] as Map<String, dynamic>?;

                        String val(dynamic v) => v == null ? "-" : v.toString();
                        final pointsAgainst = stats?["OpponentStat"]?["Points"];

                        Widget statRow(String label, dynamic value) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(label,
                                      style: const TextStyle(fontWeight: FontWeight.w600)),
                                ),
                                Text(val(value)),
                              ],
                            ),
                          );
                        }

                        return SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Team Stats ($seasonYear)",
                                  style: const TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 10),
                              if (stats == null)
                                const Text("No stats found for this season.")
                              else ...[
                                const Text("Radar Overview",
                                    style: TextStyle(fontWeight: FontWeight.w600)),
                                const SizedBox(height: 8),
                                _radarStatsChart(stats),
                                const SizedBox(height: 12),
                                const Text("Points Comparison",
                                    style: TextStyle(fontWeight: FontWeight.w600)),
                                const SizedBox(height: 8),
                                _ppgBarChart(stats),
                                const SizedBox(height: 12),
                                statRow("Wins", stats["Wins"]),
                                statRow("Losses", stats["Losses"]),
                                statRow("Games", stats["Games"]),
                                statRow("Points For", stats["Points"]),
                                statRow("Points Against", pointsAgainst),
                                statRow("FG %", stats["FieldGoalsPercentage"]),
                                statRow("3PT %", stats["ThreePointersPercentage"]),
                                statRow("Rebounds", stats["Rebounds"]),
                                statRow("Assists", stats["Assists"]),
                                statRow("Turnovers", stats["Turnovers"]),
                              ],
                              const SizedBox(height: 14),
                              Text("Players (${players.length})",
                                  style: const TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              ...players.map((p) {
                                final name = "${p["FirstName"] ?? ""} ${p["LastName"] ?? ""}".trim();
                                final pos = val(p["Position"]);
                                final jersey = val(p["Jersey"]);
                                return Column(
                                  children: [
                                    ListTile(
                                      dense: true,
                                      contentPadding: EdgeInsets.zero,
                                      title: Text(
                                        name.isEmpty ? "Player" : name,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      subtitle: Text("Pos: $pos • Jersey: $jersey"),
                                    ),
                                    const Divider(height: 1),
                                  ],
                                );
                              }),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Divider(height: 1),
                  const SizedBox(height: 10),
                  Center(
                    child: SizedBox(
                      width: 180,
                      height: 44,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text("Close"),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _openUefaTeamPopup(dynamic teamItem) async {
    final teamObj = teamItem["team"];
    final teamId = teamObj?["id"];
    final teamName = teamObj?["name"]?.toString() ?? teamItem["name"]?.toString() ?? "Team";
    final teamLogo = (teamObj?["logo"] ?? teamItem["logo"])?.toString();

    if (teamId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Team id not found for this UEFA team")),
      );
      return;
    }

    final int seasonYear = season ?? 2026;
    final int competitionId =
        int.tryParse((_selectedLeague?["competitionId"] ?? "3").toString()) ?? 3;

    showDialog(
      context: context,
      builder: (ctx) {
        final screenW = MediaQuery.of(ctx).size.width;
        final screenH = MediaQuery.of(ctx).size.height;

        final dialogW = math.min(screenW * 0.90, 950.0);
        final dialogH = screenH * 0.82;

        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: SizedBox(
            width: dialogW,
            height: dialogH,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Column(
                children: [
                  Row(
                    children: [
                      SizedBox(
                        width: 28,
                        height: 28,
                        child: _teamLogo(teamLogo, size: 28, fallback: Icons.sports_soccer),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          teamName,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 10),
                  Expanded(
                    child: FutureBuilder(
                      future: Future.wait([
                        _fetchUefaTeamPlayers(teamId, competitionId: competitionId),
                        _fetchUefaTeamStats(
                          teamId,
                          seasonYear: seasonYear,
                          competitionId: competitionId,
                        ),
                      ]),
                      builder: (context, snap) {
                        if (snap.connectionState != ConnectionState.done) {
                          return const Center(child: CircularProgressIndicator());
                        }

                        if (snap.hasError) {
                          return Center(
                            child: Text("Failed to load.\n${snap.error}",
                                textAlign: TextAlign.center),
                          );
                        }

                        final results = snap.data as List;
                        final players = results[0] as List;
                        final statsWrap = results[1] as Map<String, dynamic>?;
                        final stats = (statsWrap?["stats"] is Map)
                            ? Map<String, dynamic>.from(statsWrap!["stats"])
                            : <String, dynamic>{};

                        String val(dynamic v) => v == null ? "-" : v.toString();

                        Widget statRow(String label, dynamic value) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(label,
                                      style: const TextStyle(fontWeight: FontWeight.w600)),
                                ),
                                Text(val(value)),
                              ],
                            ),
                          );
                        }

                        String playerName(dynamic p) {
                          final common = p["commonName"]?.toString().trim() ?? "";
                          if (common.isNotEmpty) return common;

                          final fn = p["firstName"]?.toString() ?? "";
                          final ln = p["lastName"]?.toString() ?? "";
                          final full = "$fn $ln".trim();
                          return full.isEmpty ? "Player" : full;
                        }

                        return SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Team Stats ($seasonYear)",
                                  style: const TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 10),
                              if (stats.isEmpty)
                                const Text("No stats found for this season.")
                              else ...[
                                const Text("Radar Overview",
                                    style: TextStyle(fontWeight: FontWeight.w600)),
                                const SizedBox(height: 8),
                                _soccerRadarChart(stats),
                                const SizedBox(height: 14),
                                const Text("Goals Comparison",
                                    style: TextStyle(fontWeight: FontWeight.w600)),
                                const SizedBox(height: 8),
                                _soccerGoalsBarChart(stats),
                                const SizedBox(height: 14),
                                const Text("Discipline & Set Pieces",
                                    style: TextStyle(fontWeight: FontWeight.w600)),
                                const SizedBox(height: 8),
                                _soccerDisciplineBarChart(stats),
                                const SizedBox(height: 14),
                                const Text("Attacking Build-up",
                                    style: TextStyle(fontWeight: FontWeight.w600)),
                                const SizedBox(height: 8),
                                _soccerAttackBarChart(stats),
                                const SizedBox(height: 14),
                              ],
                              const SizedBox(height: 14),
                              Text("Players (${players.length})",
                                  style: const TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              ...players.map((p) {
                                final pos = val(p["position"]);
                                final jersey = val(p["jersey"]);
                                final nationality = val(p["nationality"]);

                                return Column(
                                  children: [
                                    ListTile(
                                      dense: true,
                                      contentPadding: EdgeInsets.zero,
                                      title: Text(
                                        playerName(p),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      subtitle: Text(
                                        "Pos: $pos • Jersey: $jersey • $nationality",
                                      ),
                                    ),
                                    const Divider(height: 1),
                                  ],
                                );
                              }),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Divider(height: 1),
                  const SizedBox(height: 10),
                  Center(
                    child: SizedBox(
                      width: 180,
                      height: 44,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text("Close"),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  bool _isSvgUrl(String url) => url.toLowerCase().contains(".svg");

  Widget _teamLogo(String? url, {double size = 24, IconData fallback = Icons.sports_basketball}) {
    if (url == null || url.trim().isEmpty) {
      return SizedBox(width: size, height: size, child: Icon(fallback, size: size));
    }

    final u = url.trim();

    if (_isSvgUrl(u)) {
      return SvgPicture.network(
        u,
        width: size,
        height: size,
        placeholderBuilder: (_) => SizedBox(
          width: size,
          height: size,
          child: const Center(
            child: SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2)),
          ),
        ),
      );
    }

    return Image.network(
      u,
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => SizedBox(width: size, height: size, child: Icon(fallback, size: size)),
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return SizedBox(
          width: size,
          height: size,
          child: const Center(
            child: SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2)),
          ),
        );
      },
    );
  }

  Widget _standingsTile(dynamic team) {
    final league = _selectedLeague ?? {};
    final isSoccer = (league["sport"] ?? "") == "soccer";

    final rank = team["rank"]?.toString() ?? "-";
    final points = team["points"]?.toString();

    final teamObj = team["team"];
    final name = teamObj?["name"]?.toString() ?? team["name"]?.toString() ?? "Team";
    final logo = (teamObj?["logo"] ?? team["logo"]) as String?;

    final all = team["all"];
    final played = all?["played"];
    final win = all?["win"];
    final draw = all?["draw"];
    final lose = all?["lose"];

    final hasStats = played != null && win != null && lose != null;

    return ListTile(
      leading: Text(rank, style: const TextStyle(fontWeight: FontWeight.bold)),
      title: Row(
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: _teamLogo(
              logo,
              size: 24,
              fallback: isSoccer ? Icons.sports_soccer : Icons.sports_basketball,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(name)),
        ],
      ),
      trailing: points != null
          ? Text(
              "$points pts",
              style: const TextStyle(fontWeight: FontWeight.bold),
            )
          : null,
      subtitle: hasStats
          ? Text("P:$played  W:$win  D:${draw ?? 0}  L:$lose",
              style: const TextStyle(fontSize: 12))
          : null,
    );
  }

  Widget _fixtureTile(dynamic item) {
    final homeName = item["teams"]?["home"]?["name"]?.toString() ?? "HOME";
    final awayName = item["teams"]?["away"]?["name"]?.toString() ?? "AWAY";

    final homeLogo = item["teams"]?["home"]?["logo"]?.toString();
    final awayLogo = item["teams"]?["away"]?["logo"]?.toString();

    final rawDate = item["fixture"]?["date"]?.toString();
    final dateLabel = _fmtPrettyDateTime(rawDate);

    final statusShort = item["fixture"]?["status"]?["short"]?.toString().toUpperCase() ?? "";

    final hs = item["goals"]?["home"];
    final as = item["goals"]?["away"];

    final roundName = item["league"]?["round"]?.toString();

    final bool hasScore = hs != null && as != null;
    final bool isFinal = statusShort == "FT";
    final bool isBasketball = (selectedSport == "basketball");

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 42,
                height: 42,
                child: _teamLogo(
                  homeLogo,
                  size: 42,
                  fallback: isBasketball ? Icons.sports_basketball : Icons.sports_soccer,
                ),
              ),
              const SizedBox(width: 18),
              const Text(
                "VS",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, letterSpacing: 1.2),
              ),
              const SizedBox(width: 18),
              SizedBox(
                width: 42,
                height: 42,
                child: _teamLogo(
                  awayLogo,
                  size: 42,
                  fallback: isBasketball ? Icons.sports_basketball : Icons.sports_soccer,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 14),
                  child: Text(
                    homeName,
                    textAlign: TextAlign.left,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 14),
                  child: Text(
                    awayName,
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (hasScore || isFinal)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                hasScore ? "$hs - $as" : "Final",
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          if (roundName != null && roundName.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                roundName,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.black54,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          Text(
            dateLabel,
            style: const TextStyle(fontSize: 12, color: Colors.black54, letterSpacing: 0.5),
          ),
          const SizedBox(height: 10),
          if (isBasketball)
            Align(
              alignment: Alignment.center,
              child: OutlinedButton.icon(
                onPressed: () => _openMatchPopup(item),
                icon: const Icon(Icons.people_alt_outlined),
                label: const Text("Lineups & H2H"),
              ),
            ),
          const SizedBox(height: 6),
          const Divider(height: 1),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final newToken = ++_requestToken;

      setState(() {
        selectedLeagueId = 12;
        selectedSport = "basketball";
        season = null;

        loading = true;
        errorText = null;
        isExpanded = false;
        standings = [];

        fixturesLoading = true;
        fixtures = [];
        selectedDate = DateTime.now();
      });

      await fetchStandings(newToken);
      await fetchFixturesByDate(newToken);
    });
  }

  @override
  Widget build(BuildContext context) {
    final league = _selectedLeague ?? {};
    final supportsFixtures = league["supportsFixtures"] == true;

    final bool hasSelection = selectedLeagueId != null && selectedSport != null;
    final shownTeams = isExpanded ? standings : standings.take(3).toList();
    final bool noData = !loading && hasSelection && errorText == null && standings.isEmpty;

    return Column(
      children: [
        SizedBox(
          height: 50,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: leagues.length,
            itemBuilder: (context, index) {
              final leagueItem = leagues[index];
              final leagueId = leagueItem["id"] as int;
              final sport = leagueItem["sport"] as String;

              final isSelected = selectedLeagueId == leagueId;

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: ChoiceChip(
                  label: Text(leagueItem["name"]),
                  selected: isSelected,
                  onSelected: (_) async {
                    final newToken = ++_requestToken;

                    final supportsFix = leagueItem["supportsFixtures"] == true;

                    setState(() {
                      selectedLeagueId = leagueId;
                      selectedSport = sport;
                      season = (sport == "soccer") ? 2026 : null;

                      loading = true;
                      errorText = null;
                      isExpanded = false;
                      standings = [];

                      fixturesLoading = supportsFix;
                      fixtures = [];
                      fixturesFilter = FixturesFilter.byDate;

                      if (sport == "soccer") {
                        selectedDate = DateTime.now();
                      } else {
                        selectedDate = DateTime.now();
                      }
                    });

                    await fetchStandings(newToken);

                    if (supportsFix) {
                      await fetchFixturesByDate(newToken);
                    } else {
                      if (!mounted || newToken != _requestToken) return;
                      setState(() {
                        fixturesLoading = false;
                        fixtures = [];
                      });
                    }
                  },
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: !hasSelection
              ? const Center(child: Text("Select a league to view standings"))
              : loading
                  ? const Center(child: CircularProgressIndicator())
                  : errorText != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text("Error:\n$errorText", textAlign: TextAlign.center),
                          ),
                        )
                      : noData
                          ? const Center(child: Text("No standings found"))
                          : ListView(
                              children: [
                                ListView.builder(
                                  key: ValueKey("$selectedLeagueId-$isExpanded-$selectedSport"),
                                  itemCount: shownTeams.length + (standings.length > 3 ? 1 : 0),
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemBuilder: (context, index) {
                                    if (standings.length > 3 && index == shownTeams.length) {
                                      return InkWell(
                                        onTap: () => setState(() => isExpanded = !isExpanded),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 10,
                                            horizontal: 16,
                                          ),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Text(
                                                isExpanded ? "Tap to collapse" : "Tap to expand",
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.blue,
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              Icon(
                                                isExpanded
                                                    ? Icons.keyboard_arrow_up
                                                    : Icons.keyboard_arrow_down,
                                                color: Colors.blue,
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    }

                                    final item = shownTeams[index];
                                    final isBasketball = (league["sport"] ?? "") == "basketball";
                                    final isSoccer = (league["sport"] ?? "") == "soccer";

                                    return InkWell(
                                      onTap: isBasketball
                                          ? () => _openTeamPopup(item)
                                          : isSoccer
                                              ? () => _openUefaTeamPopup(item)
                                              : null,
                                      child: _standingsTile(item),
                                    );
                                  },
                                ),
                                if (supportsFixtures) ...[
                                  const Divider(height: 24),
                                  const Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 12),
                                    child: Row(
                                      children: [
                                        Text(
                                          "Fixtures",
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  _byDateFilterControl(),
                                  const SizedBox(height: 10),
                                  if (fixturesLoading)
                                    const Padding(
                                      padding: EdgeInsets.symmetric(vertical: 20),
                                      child: Center(child: CircularProgressIndicator()),
                                    )
                                  else if (fixtures.isEmpty)
                                    const Padding(
                                      padding: EdgeInsets.symmetric(vertical: 20),
                                      child: Center(child: Text("No fixtures found")),
                                    )
                                  else
                                    ListView.separated(
                                      itemCount: fixtures.length,
                                      shrinkWrap: true,
                                      physics: const NeverScrollableScrollPhysics(),
                                      separatorBuilder: (_, __) => const SizedBox.shrink(),
                                      itemBuilder: (context, i) => _fixtureTile(fixtures[i]),
                                    ),
                                ],
                                const SizedBox(height: 20),
                              ],
                            ),
        ),
      ],
    );
  }
}

class _MatchDetailsCache {
  final String dateYmd;
  final String homeName;
  final String awayName;
  final String homeCode;
  final String awayCode;

  final Map<String, dynamic>? h2h;
  final Map<String, dynamic>? lineups;

  _MatchDetailsCache({
    required this.dateYmd,
    required this.homeName,
    required this.awayName,
    required this.homeCode,
    required this.awayCode,
    required this.h2h,
    required this.lineups,
  });
}

class _RadarMetric {
  final String label;
  final double value;
  _RadarMetric(this.label, this.value);
}

class _RadarPainter extends CustomPainter {
  final List<_RadarMetric> metrics;
  _RadarPainter({required this.metrics});

  @override
  void paint(Canvas canvas, Size size) {
    if (metrics.isEmpty) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) * 0.34;

    final gridPaint = Paint()
      ..color = Colors.black12
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    final axisPaint = Paint()
      ..color = Colors.black26
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    final areaPaint = Paint()
      ..color = Colors.blue.withOpacity(0.18)
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = Colors.blue.withOpacity(0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    for (int r = 1; r <= 3; r++) {
      final rr = radius * (r / 3.0);
      final path = Path();
      for (int i = 0; i < metrics.length; i++) {
        final a = (-math.pi / 2) + (2 * math.pi * i / metrics.length);
        final p = center + Offset(math.cos(a) * rr, math.sin(a) * rr);
        if (i == 0) {
          path.moveTo(p.dx, p.dy);
        } else {
          path.lineTo(p.dx, p.dy);
        }
      }
      path.close();
      canvas.drawPath(path, gridPaint);
    }

    for (int i = 0; i < metrics.length; i++) {
      final a = (-math.pi / 2) + (2 * math.pi * i / metrics.length);
      final end = center + Offset(math.cos(a) * radius, math.sin(a) * radius);
      canvas.drawLine(center, end, axisPaint);

      final labelOffset =
          center + Offset(math.cos(a) * (radius + 18), math.sin(a) * (radius + 18));

      final tp = TextPainter(
        text: TextSpan(
          text: metrics[i].label,
          style: const TextStyle(
            fontSize: 11,
            color: Colors.black87,
            fontWeight: FontWeight.w600,
          ),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout();

      final drawAt = Offset(labelOffset.dx - tp.width / 2, labelOffset.dy - tp.height / 2);
      tp.paint(canvas, drawAt);
    }

    final poly = Path();
    for (int i = 0; i < metrics.length; i++) {
      final a = (-math.pi / 2) + (2 * math.pi * i / metrics.length);
      final rr = radius * metrics[i].value.clamp(0.0, 1.0);
      final p = center + Offset(math.cos(a) * rr, math.sin(a) * rr);

      if (i == 0) {
        poly.moveTo(p.dx, p.dy);
      } else {
        poly.lineTo(p.dx, p.dy);
      }
    }
    poly.close();

    canvas.drawPath(poly, areaPaint);
    canvas.drawPath(poly, borderPaint);
    canvas.drawCircle(center, 3, Paint()..color = Colors.blue);
  }

  @override
  bool shouldRepaint(covariant _RadarPainter oldDelegate) {
    if (oldDelegate.metrics.length != metrics.length) return true;
    for (int i = 0; i < metrics.length; i++) {
      if (oldDelegate.metrics[i].value != metrics[i].value) return true;
    }
    return false;
  }
}