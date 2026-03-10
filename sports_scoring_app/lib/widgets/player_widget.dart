// lib/widgets/player_widget.dart
import 'package:flutter/material.dart';
import 'api_service.dart';

class PlayerWidget extends StatefulWidget {
  final int teamId;
  final int season;
  const PlayerWidget({required this.teamId, required this.season, super.key});

  @override
  State<PlayerWidget> createState() => _PlayerWidgetState();
}

class _PlayerWidgetState extends State<PlayerWidget> {
  final api = ApiService();
  late Future<List<dynamic>> players;

  @override
  void initState() {
    super.initState();
    players = api.getPlayers(widget.teamId, widget.season);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Players")),
      body: FutureBuilder<List<dynamic>>(
        future: players,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text("No players found"));
          }

          return ListView.builder(
            itemCount: snapshot.data!.length,
            itemBuilder: (context, index) {
              final player = snapshot.data![index]['player'];
              return ListTile(
                leading: CircleAvatar(
                  backgroundImage: NetworkImage(player['photo']),
                ),
                title: Text(player['name']),
                subtitle: Text(player['position']),
              );
            },
          );
        },
      ),
    );
  }
}
