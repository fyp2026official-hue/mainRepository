import 'teams.dart';

class MatchData {
  final String venue;
  final int overs;
  final List<Team> teams;
  final String tossWinner;
  final String tossDecision;

  MatchData({
    required this.venue,
    required this.overs,
    required this.teams,
    required this.tossWinner,
    required this.tossDecision,
  });
}
