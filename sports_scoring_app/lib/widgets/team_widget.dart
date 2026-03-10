// lib/widgets/team_widget.dart
import 'package:flutter/material.dart';
import 'api_service.dart';
import 'player_widget.dart';

class TeamWidget extends StatefulWidget {
  final int teamId;
  const TeamWidget({required this.teamId, super.key});

  @override
  State<TeamWidget> createState() => _TeamWidgetState();
}

class _TeamWidgetState extends State<TeamWidget> {
  final api = ApiService();
  late Future<Map<String, dynamic>> teamData;

  @override
  void initState() {
    super.initState();
    teamData = api.getTeam(widget.teamId);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: teamData,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text("Error: ${snapshot.error}"));
        }

        final team = snapshot.data!;
        return Card(
          margin: const EdgeInsets.all(8),
          child: ListTile(
            leading: Image.network(team['team']['logo'], width: 40),
            title: Text(team['team']['name']),
            subtitle: Text("Founded: ${team['team']['founded']}"),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      PlayerWidget(teamId: widget.teamId, season: DateTime.now().year),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
