import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/teams.dart';
import '../../models/match_data.dart';
import '../modals/toss_modal.dart';
import '../startmatch/initiate_match_screen.dart';
import '../tournaments/tournaments_screen.dart';

class StartMatchScreen extends StatefulWidget {
  const StartMatchScreen({super.key});

  @override
  State<StartMatchScreen> createState() => _StartMatchScreenState();
}

class _StartMatchScreenState extends State<StartMatchScreen> {
  final TextEditingController venueCtrl = TextEditingController();
  final TextEditingController oversCtrl = TextEditingController();

  final List<Team> teams = [Team()];

  String? tossWinner;
  String? tossDecision;

  void addTeam() {
    if (teams.length >= 2) {
      showError('Only 2 teams allowed');
      return;
    }
    setState(() => teams.add(Team()));
  }

  void addPlayer(Team team) {
    final name = team.playerCtrl.text.trim();
    if (name.isEmpty) return;

    setState(() {
      team.players.add(name);
      team.playerCtrl.clear();
    });
  }

  Future<void> openTossModal() async {
    final result = await showModalBottomSheet<Map<String, String>>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => TossModal(teams: teams),
    );

    if (result != null) {
      setState(() {
        tossWinner = result['winner'];
        tossDecision = result['decision'];
      });
    }
  }

  void startMatch() {
    if (venueCtrl.text.trim().isEmpty) {
      showError('Enter venue');
      return;
    }

    if (oversCtrl.text.isEmpty ||
        int.tryParse(oversCtrl.text) == null ||
        int.parse(oversCtrl.text) <= 0) {
      showError('Enter valid overs');
      return;
    }

    if (teams.length != 2) {
      showError('Add exactly 2 teams');
      return;
    }

    for (final team in teams) {
      if (team.name.trim().isEmpty) {
        showError('Enter team names');
        return;
      }
      if (team.players.isEmpty) {
        showError('Add players to ${team.name}');
        return;
      }
    }

    if (tossWinner == null || tossDecision == null) {
      showError('Complete toss');
      return;
    }

    debugPrint('Venue: ${venueCtrl.text}');
    debugPrint('Overs: ${oversCtrl.text}');
    debugPrint('Toss: $tossWinner -> $tossDecision');

    final matchData = MatchData(
      venue: venueCtrl.text.trim(),
      overs: int.parse(oversCtrl.text),
      teams: teams,
      tossWinner: tossWinner!,
      tossDecision: tossDecision!,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InitiatMatchScreen(matchData: matchData),
      ),
    );
  }

  void showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  @override
  void dispose() {
    venueCtrl.dispose();
    oversCtrl.dispose();
    for (final team in teams) {
      team.teamNameCtrl.dispose();
      team.playerCtrl.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,

      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          height: 52,
          child: ElevatedButton(
            onPressed: startMatch,
            child: const Text('Start the Match'),
          ),
        ),
      ),

      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.location_on),
                    label: const Text('View Nearby Tournaments'),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const TournamentsScreen(),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                inputBox('Enter Venue', venueCtrl),
                const SizedBox(height: 12),
                inputBox(
                  'Number of Overs',
                  oversCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  ...teams.map((team) => buildTeam(team)).toList(),
                  Row(
                    children: [
                      Expanded(child: actionButton('+ Add Team', addTeam)),
                      const SizedBox(width: 12),
                      Expanded(child: actionButton('Toss', openTossModal)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildTeam(Team team) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        inputBox(
          'Team Name',
          team.teamNameCtrl,
          onChanged: (v) => team.name = v,
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: team.playerCtrl,
                style: const TextStyle(color: Colors.black),
                decoration: InputDecoration(
                  hintText: 'Player name',
                  filled: true,
                  fillColor: const Color(0xFFE5E5E5),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 14,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.check, color: Colors.black),
              onPressed: () => addPlayer(team),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...team.players.map(
          (p) => Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 4),
            child: Text(
              '• $p',
              style: const TextStyle(color: Colors.black),
            ),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget inputBox(
    String hint,
    TextEditingController controller, {
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    ValueChanged<String>? onChanged,
  }) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      style: const TextStyle(color: Colors.black),
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: const Color(0xFFE5E5E5),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget actionButton(String text, VoidCallback onTap) {
    return ElevatedButton(
      onPressed: onTap,
      child: Text(text),
    );
  }
}