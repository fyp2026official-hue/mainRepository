import 'package:flutter/material.dart';
import '../../models/match_data.dart';
import '../home/home_screen.dart';

class SummaryScreen extends StatelessWidget {
  final MatchData matchData;
  final int firstInningScore;
  final int secondInningScore;
  final String winner;

  // ✅ New optional fields
  final int? target;
  final List<Map<String, dynamic>>? innings;
  final Map<String, dynamic>? matchSummary;

  const SummaryScreen({
    super.key,
    required this.matchData,
    required this.firstInningScore,
    required this.secondInningScore,
    required this.winner,
    this.target,
    this.innings,
    this.matchSummary,
  });

  @override
  Widget build(BuildContext context) {
    final inning1 = innings != null && innings!.isNotEmpty ? innings![0] : null;
    final inning2 = innings != null && innings!.length > 1 ? innings![1] : null;

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
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Text(
                      'Match Summary',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),

                    const SizedBox(height: 20),

                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            summaryCard(
                              title: 'Match Details',
                              content:
                                  'Venue: ${matchData.venue}\n'
                                  'Overs: ${matchData.overs}\n'
                                  'Toss Winner: ${matchData.tossWinner}\n'
                                  'Toss Decision: ${matchData.tossDecision}',
                            ),

                            const SizedBox(height: 16),

                            summaryCard(
                              title: 'Scores',
                              content:
                                  '${matchData.teams[0].name}: $firstInningScore\n'
                                  '${matchData.teams[1].name}: $secondInningScore\n'
                                  '${target != null ? "Target: $target" : ""}',
                            ),

                            const SizedBox(height: 16),

                            summaryCard(
                              title: 'Result',
                              content: 'Winner: $winner',
                            ),

                            if (inning1 != null) ...[
                              const SizedBox(height: 16),
                              inningsCard(
                                title: '1st Innings',
                                inning: inning1,
                              ),
                            ],

                            if (inning2 != null) ...[
                              const SizedBox(height: 16),
                              inningsCard(
                                title: '2nd Innings',
                                inning: inning2,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE5E5E5),
                          elevation: 0,
                        ),
                        onPressed: () {
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const HomeScreen(),
                            ),
                            (route) => false,
                          );
                        },
                        child: const Text(
                          'Continue to Home',
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget summaryCard({
    required String title,
    required String content,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFE5E5E5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  static Widget inningsCard({
    required String title,
    required Map<String, dynamic> inning,
  }) {
    final battingStats = (inning["battingStats"] as List?) ?? [];
    final bowlingStats = (inning["bowlingStats"] as List?) ?? [];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFE5E5E5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 8),

          Text(
            'Batting Team: ${inning["battingTeam"]}\n'
            'Bowling Team: ${inning["bowlingTeam"]}\n'
            'Score: ${inning["scoreText"]}\n'
            'Overs: ${inning["oversText"]}\n'
            'Extras: ${inning["extras"]}',
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black87,
            ),
          ),

          if (battingStats.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text(
              'Batting Stats',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            ...battingStats.map(
              (player) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '${player["playerName"]}: '
                  '${player["runs"]} (${player["ballsFaced"]}) '
                  '${player["isOut"] == true ? "- ${player["dismissal"]}" : "- Not Out"}',
                  style: const TextStyle(color: Colors.black87),
                ),
              ),
            ),
          ],

          if (bowlingStats.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text(
              'Bowling Stats',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            ...bowlingStats.map(
              (player) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '${player["playerName"]}: '
                  '${player["oversText"]} overs, '
                  '${player["runsConceded"]} runs, '
                  '${player["wickets"]} wickets',
                  style: const TextStyle(color: Colors.black87),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}