// lib/widgets/league_details_widget.dart
import 'package:flutter/material.dart';
import 'api_service.dart';
import 'standings_widget.dart';
import 'games_widget.dart';

class LeagueDetailsWidget extends StatefulWidget {
  final int leagueId;
  const LeagueDetailsWidget({required this.leagueId, super.key});

  @override
  State<LeagueDetailsWidget> createState() => _LeagueDetailsWidgetState();
}

class _LeagueDetailsWidgetState extends State<LeagueDetailsWidget>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("League Details"),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: "Games"),
            Tab(text: "Standings"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          GamesWidget(league: widget.leagueId.toString()),
          StandingsWidget(leagueId: widget.leagueId, season: DateTime.now().year),
        ],
      ),
    );
  }
}
