// lib/widgets/leagues_widget.dart
import 'package:flutter/material.dart';
import 'api_service.dart';
import 'league_details_widget.dart';

class LeaguesWidget extends StatefulWidget {
  final int? season;
  const LeaguesWidget({this.season, super.key});

  @override
  State<LeaguesWidget> createState() => _LeaguesWidgetState();
}

class _LeaguesWidgetState extends State<LeaguesWidget> {
  final api = ApiService();
  late Future<List<dynamic>> leagues;

  @override
  void initState() {
    super.initState();
    leagues = api.getLeagues(season: widget.season);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: leagues,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text("Error: ${snapshot.error}"));
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text("No leagues found"));
        }

        return ListView.builder(
          itemCount: snapshot.data!.length,
          itemBuilder: (context, index) {
            final league = snapshot.data![index]['league'];
            final country = snapshot.data![index]['country'];
            return Card(
              margin: const EdgeInsets.all(8),
              child: ListTile(
                leading: Image.network(league['logo'], width: 40),
                title: Text("${league['name']} (${country['name']})"),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          LeagueDetailsWidget(leagueId: league['id']),
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
