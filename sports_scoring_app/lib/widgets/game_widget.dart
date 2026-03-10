import 'package:flutter/material.dart';
import 'api_service.dart';
import 'game_details_widget.dart';

class GamesWidget extends StatefulWidget {
  final String? date;
  final String? league;
  const GamesWidget({this.date, this.league, super.key});

  @override
  State<GamesWidget> createState() => _GamesWidgetState();
}

class _GamesWidgetState extends State<GamesWidget> {
  final api = ApiService();
  late Future<List<dynamic>> games;

  @override
  void initState() {
    super.initState();
    games = api.getGames(date: widget.date, league: widget.league);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: games,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text("Error: ${snapshot.error}"));
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text("No games found"));
        }

        return ListView.builder(
          itemCount: snapshot.data!.length,
          itemBuilder: (context, index) {
            final game = snapshot.data![index]['fixture'];
            final home = snapshot.data![index]['teams']['home'];
            final away = snapshot.data![index]['teams']['away'];
            final score = snapshot.data![index]['score']['fulltime'];

            return Card(
              margin: const EdgeInsets.all(8),
              child: ListTile(
                leading: Image.network(home['logo'], width: 40),
                title: Text("${home['name']} vs ${away['name']}"),
                subtitle: Text(score != null
                    ? "${score['home']} - ${score['away']}"
                    : "Scheduled: ${game['date']}"),
                trailing: Image.network(away['logo'], width: 40),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          GameDetailsWidget(fixtureId: game['id']),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}
