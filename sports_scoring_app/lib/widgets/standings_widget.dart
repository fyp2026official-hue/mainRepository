// lib/widgets/standings_widget.dart
import 'package:flutter/material.dart';
import 'api_service.dart';

class StandingsWidget extends StatefulWidget {
  final int leagueId;
  final int season;
  const StandingsWidget({required this.leagueId, required this.season, super.key});

  @override
  State<StandingsWidget> createState() => _StandingsWidgetState();
}

class _StandingsWidgetState extends State<StandingsWidget> {
  final api = ApiService();
  late Future<List<dynamic>> standings;

  @override
  void initState() {
    super.initState();
    standings = api.getStandings(widget.leagueId, widget.season);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: standings,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text("Error: ${snapshot.error}"));
        }

        final data = snapshot.data ?? [];
        return ListView.builder(
          itemCount: data.length,
          itemBuilder: (context, index) {
            final team = data[index];
            return ListTile(
              leading: Text("${team['rank']}"),
              title: Text(team['team']['name']),
              trailing: Text("${team['points']} pts"),
            );
          },
        );
      },
    );
  }
}
