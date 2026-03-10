import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../models/match_data.dart';
import '../../models/teams.dart';
import '../modals/player_selection_dialog.dart';
import '../summary/summary_screen.dart';

class ScoreScreen extends StatefulWidget {
  final MatchData matchData;

  const ScoreScreen({
    super.key,
    required this.matchData,
  });

  @override
  State<ScoreScreen> createState() => _ScoreScreenState();
}

class _ScoreScreenState extends State<ScoreScreen> {
  late Team battingTeam;
  late Team bowlingTeam;

  String? striker;
  String? nonStriker;
  String? bowler;

  int runs = 0;
  int wickets = 0;
  int overs = 0;
  int balls = 0;

  int? target;
  int? firstInningScore;

  bool noBallActive = false;
  bool wideBallActive = false;
  bool lbwActive = false; // treated as leg-bye style extra
  bool firstInning = true;

  final Map<String, Map<String, BattingStats>> battingStatsByTeam = {};
  final Map<String, Map<String, BowlingStats>> bowlingStatsByTeam = {};
  final Map<String, int> extrasByTeam = {};
  final List<Map<String, dynamic>> inningsHistory = [];

  @override
  void initState() {
    super.initState();

    final teamA = widget.matchData.teams[0];
    final teamB = widget.matchData.teams[1];

    _prepareTeamStats(teamA);
    _prepareTeamStats(teamB);

    final tossWinner = widget.matchData.tossWinner;
    final tossDecision = widget.matchData.tossDecision;

    if (tossWinner == teamA.name) {
      battingTeam = tossDecision == 'Bat' ? teamA : teamB;
      bowlingTeam = tossDecision == 'Bat' ? teamB : teamA;
    } else {
      battingTeam = tossDecision == 'Bat' ? teamB : teamA;
      bowlingTeam = tossDecision == 'Bat' ? teamA : teamB;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      selectInitialPlayers();
    });
  }

  void _prepareTeamStats(Team team) {
    battingStatsByTeam[team.name] = {
      for (final player in team.players)
        player: BattingStats(playerName: player),
    };

    bowlingStatsByTeam[team.name] = {
      for (final player in team.players)
        player: BowlingStats(playerName: player),
    };

    extrasByTeam[team.name] = 0;
  }

  Map<String, BattingStats> get _currentBattingStats =>
      battingStatsByTeam[battingTeam.name] ?? {};

  Map<String, BowlingStats> get _currentBowlingStats =>
      bowlingStatsByTeam[bowlingTeam.name] ?? {};

  BattingStats? get _strikerStats =>
      striker != null ? _currentBattingStats[striker!] : null;

  BowlingStats? get _bowlerStats =>
      bowler != null ? _currentBowlingStats[bowler!] : null;

  void selectInitialPlayers() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => PlayerSelectionDialog(
        battingTeam: battingTeam,
        bowlingTeam: bowlingTeam,
        onConfirm: (s, ns, b) {
          setState(() {
            striker = s;
            nonStriker = ns;
            bowler = b;
          });
        },
      ),
    );
  }

  void selectNextBowler() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => PlayerSelectionDialog(
        bowlingTeam: bowlingTeam,
        bowlerOnly: true,
        onConfirm: (_, __, b) {
          setState(() => bowler = b);
        },
      ),
    );
  }

  void selectNextBatsman() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => PlayerSelectionDialog(
        battingTeam: battingTeam,
        batsmanOnly: true,
        onConfirm: (b, _, __) {
          setState(() => striker = b);
        },
      ),
    );
  }

  void addRun(int run) {
    if (striker == null || nonStriker == null || bowler == null) {
      showError('Select players first');
      return;
    }

    int totalRun = 0;
    int batterRuns = 0;
    int extras = 0;

    final bool isWide = wideBallActive;
    final bool isNoBall = noBallActive;
    final bool isLegBye = lbwActive;
    final bool legalDelivery = !isWide && !isNoBall;

    if (isWide) {
      extras = run + 1;
      totalRun = extras;
    } else if (isNoBall) {
      extras = 1;
      batterRuns = run;
      totalRun = extras + batterRuns;
    } else if (isLegBye) {
      extras = run;
      totalRun = extras;
    } else {
      batterRuns = run;
      totalRun = batterRuns;
    }

    bool overJustCompleted = false;

    setState(() {
      runs += totalRun;
      extrasByTeam[battingTeam.name] =
          (extrasByTeam[battingTeam.name] ?? 0) + extras;

      if (legalDelivery && _strikerStats != null) {
        _strikerStats!.ballsFaced++;
      }

      if (batterRuns > 0 && _strikerStats != null) {
        _strikerStats!.runs += batterRuns;
        if (batterRuns == 4) _strikerStats!.fours++;
        if (batterRuns == 6) _strikerStats!.sixes++;
      }

      if (_bowlerStats != null) {
        if (legalDelivery) {
          _bowlerStats!.ballsBowled++;
        }

        if (isWide || isNoBall) {
          _bowlerStats!.runsConceded += totalRun;
        } else if (!isLegBye) {
          _bowlerStats!.runsConceded += batterRuns;
        }
      }

      if (legalDelivery) {
        balls++;
        if (balls == 6) {
          overs++;
          balls = 0;
          overJustCompleted = true;
        }
      }

      if (totalRun.isOdd) {
        swapStrike();
      }

      if (overJustCompleted) {
        swapStrike();
      }

      noBallActive = false;
      wideBallActive = false;
      lbwActive = false;
    });

    if (_isTargetReached()) {
      endMatch();
      return;
    }

    if (_isInningsComplete()) {
      endInning();
      return;
    }

    if (overJustCompleted) {
      selectNextBowler();
    }
  }

  void wicket() {
    if (striker == null || bowler == null) {
      showError('Select players first');
      return;
    }

    bool overJustCompleted = false;

    setState(() {
      wickets++;

      if (_strikerStats != null) {
        _strikerStats!.ballsFaced++;
        _strikerStats!.isOut = true;
        _strikerStats!.dismissal = 'Wicket';
      }

      if (_bowlerStats != null) {
        _bowlerStats!.ballsBowled++;
        _bowlerStats!.wickets++;
      }

      balls++;
      if (balls == 6) {
        overs++;
        balls = 0;
        overJustCompleted = true;
      }

      noBallActive = false;
      wideBallActive = false;
      lbwActive = false;
    });

    if (_isInningsComplete()) {
      endInning();
      return;
    }

    if (overJustCompleted) {
      swapStrike();
      selectNextBowler();
    }

    selectNextBatsman();
  }

  void swapStrike() {
    final temp = striker;
    striker = nonStriker;
    nonStriker = temp;
  }

  bool _isTargetReached() {
    return !firstInning && target != null && runs >= target!;
  }

  bool _isAllOut() {
    return wickets >= battingTeam.players.length - 1;
  }

  bool _isOversComplete() {
    return overs >= widget.matchData.overs;
  }

  bool _isInningsComplete() {
    if (_isAllOut()) return true;
    if (_isOversComplete()) return true;
    return false;
  }

  Map<String, dynamic> _buildCurrentInningsSummary() {
    return {
      "inning": firstInning ? 1 : 2,
      "battingTeam": battingTeam.name,
      "bowlingTeam": bowlingTeam.name,
      "runs": runs,
      "wickets": wickets,
      "overs": overs,
      "balls": balls,
      "scoreText": "$runs/$wickets",
      "oversText": "$overs.$balls",
      "extras": extrasByTeam[battingTeam.name] ?? 0,
      "battingStats":
          _currentBattingStats.values.map((e) => e.toJson()).toList(),
      "bowlingStats":
          _currentBowlingStats.values.map((e) => e.toJson()).toList(),
    };
  }

  Map<String, dynamic> _buildCompleteMatchSummary(String winner) {
    return {
      "venue": widget.matchData.venue,
      "oversLimit": widget.matchData.overs,
      "tossWinner": widget.matchData.tossWinner,
      "tossDecision": widget.matchData.tossDecision,
      "teamA": widget.matchData.teams[0].name,
      "teamB": widget.matchData.teams[1].name,
      "firstInningScore": firstInningScore ?? 0,
      "secondInningScore": runs,
      "target": target,
      "winner": winner,
      "innings": inningsHistory,
      "createdAt": DateTime.now().toIso8601String(),
    };
  }

  Future<void> saveMatchHistory(Map<String, dynamic> finalSummary) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint("No logged-in user. Match history not saved.");
        return;
      }

      final token = await user.getIdToken(true);

      final response = await http.post(
        Uri.parse("http://192.168.10.9:5000/api/users/match-history"),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "venue": finalSummary["venue"],
          "oversLimit": finalSummary["oversLimit"],
          "tossWinner": finalSummary["tossWinner"],
          "tossDecision": finalSummary["tossDecision"],
          "teamA": finalSummary["teamA"],
          "teamB": finalSummary["teamB"],
          "firstInningScore": finalSummary["firstInningScore"],
          "secondInningScore": finalSummary["secondInningScore"],
          "target": finalSummary["target"],
          "winner": finalSummary["winner"],
          "innings": finalSummary["innings"],
          "summary": finalSummary,
        }),
      );

      debugPrint("SAVE MATCH HISTORY STATUS: ${response.statusCode}");
      debugPrint("SAVE MATCH HISTORY BODY: ${response.body}");
    } catch (e) {
      debugPrint("Save match history error: $e");
    }
  }

  void endInning() {
    inningsHistory.add(_buildCurrentInningsSummary());

    if (firstInning) {
      firstInningScore = runs;
      target = runs + 1;

      setState(() {
        firstInning = false;

        final temp = battingTeam;
        battingTeam = bowlingTeam;
        bowlingTeam = temp;

        runs = 0;
        wickets = 0;
        overs = 0;
        balls = 0;

        striker = null;
        nonStriker = null;
        bowler = null;

        noBallActive = false;
        wideBallActive = false;
        lbwActive = false;
      });

      selectInitialPlayers();
    } else {
      endMatch();
    }
  }

  Future<void> endMatch() async {
    if (inningsHistory.length < 2) {
      inningsHistory.add(_buildCurrentInningsSummary());
    }

    final winner =
        (target != null && runs >= target!) ? battingTeam.name : bowlingTeam.name;

    final finalSummary = _buildCompleteMatchSummary(winner);

    debugPrint("MATCH SUMMARY => $finalSummary");

    await saveMatchHistory(finalSummary);

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => SummaryScreen(
          matchData: widget.matchData,
          firstInningScore: firstInningScore ?? 0,
          secondInningScore: runs,
          winner: winner,
          target: target,
          innings: inningsHistory,
          matchSummary: finalSummary,
        ),
      ),
    );
  }

  void showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        body: Stack(
          children: [
            Positioned.fill(
              child: Image.asset(
                'assets/images/splash.png',
                fit: BoxFit.cover,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const SizedBox(height: 40),
                  Text(
                    '${battingTeam.name} Batting',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (!firstInning && target != null) Text('Target: $target'),
                  const SizedBox(height: 10),
                  Text(
                    '$runs / $wickets',
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text('Overs: $overs.$balls'),
                  Text('Extras: ${extrasByTeam[battingTeam.name] ?? 0}'),
                  const SizedBox(height: 16),
                  if (striker != null)
                    Column(
                      children: [
                        Text('Striker: $striker'),
                        Text('Non-Striker: $nonStriker'),
                        Text('Bowler: $bowler'),
                      ],
                    ),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      scoreBtn('0', () => addRun(0)),
                      for (int i = 1; i <= 8; i++)
                        scoreBtn('$i', () => addRun(i)),
                      scoreBtn('Wicket', wicket, color: Colors.red),
                      scoreBtn(
                        'No Ball',
                        () => setState(() {
                          noBallActive = true;
                          wideBallActive = false;
                          lbwActive = false;
                        }),
                        color: Colors.red,
                        active: noBallActive,
                      ),
                      scoreBtn(
                        'Wide',
                        () => setState(() {
                          wideBallActive = true;
                          noBallActive = false;
                          lbwActive = false;
                        }),
                        color: Colors.red,
                        active: wideBallActive,
                      ),
                      scoreBtn(
                        'Extra LBW',
                        () => setState(() {
                          lbwActive = true;
                          noBallActive = false;
                          wideBallActive = false;
                        }),
                        active: lbwActive,
                      ),
                    ],
                  ),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: firstInning ? endInning : endMatch,
                      child: Text(firstInning ? 'End Inning' : 'End Match'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget scoreBtn(
    String text,
    VoidCallback onTap, {
    Color color = const Color(0xFFE5E5E5),
    bool active = false,
  }) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: active ? Colors.orange : color,
        minimumSize: const Size(90, 44),
      ),
      onPressed: onTap,
      child: Text(
        text,
        style: const TextStyle(color: Colors.black),
      ),
    );
  }
}

class BattingStats {
  final String playerName;
  int runs;
  int ballsFaced;
  int fours;
  int sixes;
  bool isOut;
  String dismissal;

  BattingStats({
    required this.playerName,
    this.runs = 0,
    this.ballsFaced = 0,
    this.fours = 0,
    this.sixes = 0,
    this.isOut = false,
    this.dismissal = "Not Out",
  });

  Map<String, dynamic> toJson() {
    return {
      "playerName": playerName,
      "runs": runs,
      "ballsFaced": ballsFaced,
      "fours": fours,
      "sixes": sixes,
      "isOut": isOut,
      "dismissal": dismissal,
    };
  }
}

class BowlingStats {
  final String playerName;
  int ballsBowled;
  int runsConceded;
  int wickets;

  BowlingStats({
    required this.playerName,
    this.ballsBowled = 0,
    this.runsConceded = 0,
    this.wickets = 0,
  });

  String get oversText => "${ballsBowled ~/ 6}.${ballsBowled % 6}";

  Map<String, dynamic> toJson() {
    return {
      "playerName": playerName,
      "ballsBowled": ballsBowled,
      "oversText": oversText,
      "runsConceded": runsConceded,
      "wickets": wickets,
    };
  }
}