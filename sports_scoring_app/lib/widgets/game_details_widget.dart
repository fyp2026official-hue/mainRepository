import 'package:flutter/material.dart';
import 'api_service.dart';

class GameDetailsWidget extends StatefulWidget {
  final int fixtureId;
  const GameDetailsWidget({required this.fixtureId, super.key});

  @override
  State<GameDetailsWidget> createState() => _GameDetailsWidgetState();
}

class _GameDetailsWidgetState extends State<GameDetailsWidget>
    with SingleTickerProviderStateMixin {
  final api = ApiService();
  late Future<Map<String, dynamic>> gameDetails;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    gameDetails = api.getGameDetails(widget.fixtureId);
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Game Details"),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: "Events"),
            Tab(text: "Stats"),
            Tab(text: "Players"),
          ],
        ),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: gameDetails,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }

          final data = snapshot.data!;
          return TabBarView(
            controller: _tabController,
            children: [
              ListView.builder(
                itemCount: data['events']?.length ?? 0,
                itemBuilder: (context, index) {
                  final event = data['events'][index];
                  return ListTile(
                    title: Text(
                        "${event['time']['elapsed']}' ${event['team']['name']}"),
                    subtitle: Text("${event['player']['name']} - ${event['type']}"),
                  );
                },
              ),
              ListView.builder(
                itemCount: data['statistics']?.length ?? 0,
                itemBuilder: (context, index) {
                  final stat = data['statistics'][index];
                  return ListTile(
                    title: Text(stat['type']),
                    trailing: Text("${stat['home']} - ${stat['away']}"),
                  );
                },
              ),
              ListView.builder(
                itemCount: data['players']?.length ?? 0,
                itemBuilder: (context, index) {
                  final player = data['players'][index];
                  return ListTile(
                    title: Text(player['name']),
                    subtitle: Text(player['position']),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}
