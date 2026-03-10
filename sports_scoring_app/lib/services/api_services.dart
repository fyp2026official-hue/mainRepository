import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  final String apiKey = "b972b206cc975b7a9b276a7923de8668"; // Replace with your API key
  final String baseUrl = "https://v3.football.api-sports.io";

  Future<List<dynamic>> getGames({String? date, String? league}) async {
    final uri = Uri.parse("$baseUrl/fixtures?date=$date&league=$league");
    final response = await http.get(uri, headers: {"x-apisports-key": apiKey});
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['response'];
    } else {
      throw Exception("Failed to load games");
    }
  }

  Future<Map<String, dynamic>> getGameDetails(int fixtureId) async {
    final uri = Uri.parse("$baseUrl/fixtures?id=$fixtureId");
    final response = await http.get(uri, headers: {"x-apisports-key": apiKey});
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['response'][0];
    } else {
      throw Exception("Failed to load game details");
    }
  }

  Future<List<dynamic>> getLeagues({int? season}) async {
    final uri = Uri.parse("$baseUrl/leagues?season=$season");
    final response = await http.get(uri, headers: {"x-apisports-key": apiKey});
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['response'];
    } else {
      throw Exception("Failed to load leagues");
    }
  }

  Future<List<dynamic>> getStandings(int leagueId, int season) async {
    final uri = Uri.parse("$baseUrl/standings?league=$leagueId&season=$season");
    final response = await http.get(uri, headers: {"x-apisports-key": apiKey});
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['response'][0]['league']['standings'][0];
    } else {
      throw Exception("Failed to load standings");
    }
  }

  Future<Map<String, dynamic>> getTeam(int teamId) async {
    final uri = Uri.parse("$baseUrl/teams?id=$teamId");
    final response = await http.get(uri, headers: {"x-apisports-key": apiKey});
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['response'][0];
    } else {
      throw Exception("Failed to load team");
    }
  }

  Future<List<dynamic>> getPlayers(int teamId, int season) async {
    final uri = Uri.parse("$baseUrl/players?team=$teamId&season=$season");
    final response = await http.get(uri, headers: {"x-apisports-key": apiKey});
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['response'];
    } else {
      throw Exception("Failed to load players");
    }
  }

  Future<List<dynamic>> getH2H(int team1Id, int team2Id) async {
    final uri = Uri.parse("$baseUrl/fixtures/headtohead?h2h=$team1Id-$team2Id");
    final response = await http.get(uri, headers: {"x-apisports-key": apiKey});
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['response'];
    } else {
      throw Exception("Failed to load H2H data");
    }
  }
  // ✅ Node backend base url (add this inside ApiService class)
static const String backendBaseUrl = "http://192.168.10.9:5000";

// ✅ GET tournaments for same city (backend filters by uid->user.profile.city)
Future<List<dynamic>> getCityTournaments({required String firebaseUid}) async {
  final uri = Uri.parse("$backendBaseUrl/api/tournaments?firebaseUid=$firebaseUid");
  final response = await http.get(uri);

  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);
    return data["tournaments"] as List<dynamic>;
  } else {
    throw Exception("Failed to load tournaments: ${response.body}");
  }
}

// ✅ CREATE tournament (new separated fields)
Future<void> createTournamentDetails({
  required String firebaseUid,
  required String organizerName,
  required String contactNo,
  required double entryFee,
  required double winningPrize,
  required String venue,
}) async {
  final uri = Uri.parse("$backendBaseUrl/api/tournaments");
  final response = await http.post(
    uri,
    headers: {"Content-Type": "application/json"},
    body: jsonEncode({
      "firebaseUid": firebaseUid,
      "organizerName": organizerName,
      "contactNo": contactNo,
      "entryFee": entryFee,
      "winningPrize": winningPrize,
      "venue": venue,
    }),
  );

  if (response.statusCode != 201) {
    throw Exception("Create tournament failed: ${response.body}");
  }
}

// ✅ DELETE tournament (only creator can delete)
Future<void> deleteTournament({
  required String firebaseUid,
  required String tournamentId,
}) async {
  final uri = Uri.parse(
    "$backendBaseUrl/api/tournaments/$tournamentId?firebaseUid=$firebaseUid",
  );
  final response = await http.delete(uri);

  if (response.statusCode != 200) {
    throw Exception("Delete tournament failed: ${response.body}");
  }
}
}
  
