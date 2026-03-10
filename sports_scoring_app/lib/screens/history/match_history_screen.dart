import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../../widgets/app_drawer.dart';

class MatchHistoryScreen extends StatefulWidget {
  const MatchHistoryScreen({super.key});

  @override
  State<MatchHistoryScreen> createState() => _MatchHistoryScreenState();
}

class _MatchHistoryScreenState extends State<MatchHistoryScreen> {
  bool isLoading = true;
  String? errorText;
  List<dynamic> matches = [];

  @override
  void initState() {
    super.initState();
    fetchMatchHistory();
  }

  Future<void> fetchMatchHistory() async {
    setState(() {
      isLoading = true;
      errorText = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception("User not logged in");
      }

      final token = await user.getIdToken(true);

      final response = await http.get(
        Uri.parse("http://192.168.10.9:5000/api/users/match-history"),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
      );

      debugPrint("MATCH HISTORY STATUS: ${response.statusCode}");
      debugPrint("MATCH HISTORY BODY: ${response.body}");

      if (response.statusCode != 200) {
        throw Exception("Failed to fetch match history");
      }

      final data = jsonDecode(response.body);
      final fetchedMatches = data["matches"] ?? [];

      if (!mounted) return;
      setState(() {
        matches = fetchedMatches;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        errorText = "Failed to load match history: $e";
        isLoading = false;
      });
    }
  }

  bool isToday(DateTime dt) {
    final now = DateTime.now();
    return dt.year == now.year && dt.month == now.month && dt.day == now.day;
  }

  bool isYesterday(DateTime dt) {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return dt.year == yesterday.year &&
        dt.month == yesterday.month &&
        dt.day == yesterday.day;
  }

  String formatDateTime(String? iso) {
    if (iso == null || iso.isEmpty) return "Unknown date";
    try {
      final dt = DateTime.parse(iso).toLocal();
      final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
      final minute = dt.minute.toString().padLeft(2, '0');
      final ampm = dt.hour >= 12 ? 'PM' : 'AM';
      return "${dt.day}/${dt.month}/${dt.year}  $hour:$minute $ampm";
    } catch (_) {
      return iso;
    }
  }

  void showMatchDetails(BuildContext context, Map<String, dynamic> match) {
    final innings = (match["innings"] as List?) ?? [];

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Match Details"),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Venue: ${match["venue"] ?? "-"}"),
              Text("Overs: ${match["oversLimit"] ?? "-"}"),
              Text("Toss Winner: ${match["tossWinner"] ?? "-"}"),
              Text("Toss Decision: ${match["tossDecision"] ?? "-"}"),
              const SizedBox(height: 10),
              Text("Team A: ${match["teamA"] ?? "-"}"),
              Text("Team B: ${match["teamB"] ?? "-"}"),
              Text("1st Innings: ${match["firstInningScore"] ?? 0}"),
              Text("2nd Innings: ${match["secondInningScore"] ?? 0}"),
              if (match["target"] != null) Text("Target: ${match["target"]}"),
              Text("Winner: ${match["winner"] ?? "-"}"),
              const SizedBox(height: 12),
              Text(
                "Created: ${formatDateTime(match["createdAt"])}",
                style: const TextStyle(color: Colors.black54),
              ),
              if (innings.isNotEmpty) ...[
                const SizedBox(height: 14),
                const Text(
                  "Innings Summary",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...innings.map((inning) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(
                      "Inning ${inning["inning"]}: "
                      "${inning["battingTeam"]} scored ${inning["scoreText"]} "
                      "in ${inning["oversText"]}",
                    ),
                  );
                }),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<dynamic> todayMatches = [];
    final List<dynamic> yesterdayMatches = [];
    final List<dynamic> earlierMatches = [];

    for (final match in matches) {
      final createdAt = match["createdAt"];
      if (createdAt == null) {
        earlierMatches.add(match);
        continue;
      }

      try {
        final dt = DateTime.parse(createdAt).toLocal();
        if (isToday(dt)) {
          todayMatches.add(match);
        } else if (isYesterday(dt)) {
          yesterdayMatches.add(match);
        } else {
          earlierMatches.add(match);
        }
      } catch (_) {
        earlierMatches.add(match);
      }
    }

    return Scaffold(
      // backgroundColor: const Color(0xFF3F3F3F),
      drawer: AppDrawer(
        userName: FirebaseAuth.instance.currentUser?.displayName ?? "User",
        photoUrl: FirebaseAuth.instance.currentUser?.photoURL,
      ),
      body: Builder(
        builder: (context) => Stack(
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
                  SizedBox(
                    height: 40,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: IconButton(
                            icon: const Icon(Icons.menu, color: Colors.black),
                            onPressed: () {
                              Scaffold.of(context).openDrawer();
                            },
                          ),
                        ),
                        const Text(
                          'Match History',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: IconButton(
                            icon: const Icon(Icons.refresh, color: Colors.black),
                            onPressed: fetchMatchHistory,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Expanded(
                    child: _buildContent(
                      todayMatches: todayMatches,
                      yesterdayMatches: yesterdayMatches,
                      earlierMatches: earlierMatches,
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

  Widget _buildContent({
    required List<dynamic> todayMatches,
    required List<dynamic> yesterdayMatches,
    required List<dynamic> earlierMatches,
  }) {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.black),
      );
    }

    if (errorText != null) {
      return Center(
        child: Text(
          errorText!,
          style: const TextStyle(
            color: Colors.red,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
      );
    }

    if (matches.isEmpty) {
      return const Center(
        child: Text(
          "No match history found",
          style: TextStyle(
            color: Colors.black,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    return SingleChildScrollView(
      child: Column(
        children: [
          if (todayMatches.isNotEmpty) ...[
            sectionTitle('Today'),
            const SizedBox(height: 8),
            ...todayMatches.map((m) => historyCard(match: m)).toList(),
            const SizedBox(height: 24),
          ],
          if (yesterdayMatches.isNotEmpty) ...[
            sectionTitle('Yesterday'),
            const SizedBox(height: 8),
            ...yesterdayMatches.map((m) => historyCard(match: m)).toList(),
            const SizedBox(height: 24),
          ],
          if (earlierMatches.isNotEmpty) ...[
            sectionTitle('Earlier'),
            const SizedBox(height: 8),
            ...earlierMatches.map((m) => historyCard(match: m)).toList(),
          ],
        ],
      ),
    );
  }

  Widget sectionTitle(String text) {
    return Row(
      children: [
        Text(
          text,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        const Expanded(
          child: Divider(
            color: Colors.black,
            thickness: 0.6,
            indent: 10,
          ),
        ),
      ],
    );
  }

  Widget historyCard({required Map<String, dynamic> match}) {
    final teamA = match["teamA"] ?? "Team A";
    final teamB = match["teamB"] ?? "Team B";
    final firstScore = match["firstInningScore"] ?? 0;
    final secondScore = match["secondInningScore"] ?? 0;
    final winner = match["winner"] ?? "-";
    final venue = match["venue"] ?? "-";
    final createdAt = formatDateTime(match["createdAt"]);

    return GestureDetector(
      onTap: () => showMatchDetails(context, match),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFE5E5E5),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "$teamA vs $teamB",
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              "$teamA: $firstScore\n$teamB: $secondScore",
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              "Winner: $winner",
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black87,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              "Venue: $venue",
              style: const TextStyle(
                fontSize: 13,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              createdAt,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }
}