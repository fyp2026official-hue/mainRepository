// lib/widgets/h2h_widget.dart
import 'package:flutter/material.dart';
import 'api_service.dart';
import 'game_details_widget.dart';

class H2HWidget extends StatefulWidget {
  final int team1Id;
  final int team2Id;
  const H2HWidget({required this.team1Id, required this.team2Id, super.key});

  @override
  State<H2HWidget> createState() => _H2HWidgetState();
}

class _H2HWidgetState extends State<H2HWidget> {
  final api = ApiService();
  late Future<List<dynamic>> matches;

  @override
  void initState() {
    super.initState();
    matches = api.getH2H(widget.team1Id, widget.team2Id);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: matches,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text("Error: ${snapshot.error}"));
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text("No H2H matches found"));
        }

        return ListView.builder(
          itemCount: snapshot.data!.length,
          itemBuilder: (context, index) {
            final game = snapshot.data![index]['fixture'];
            final home = snapshot.data![index]['teams']['home'];
            final away = snapshot.data![index]['teams']['away'];
            return Card(
              margin: const EdgeInsets.all(8),
              child: ListTile(
                title: Text("${home['name']} vs ${away['name']}"),
                subtitle: Text(game['date']),
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
