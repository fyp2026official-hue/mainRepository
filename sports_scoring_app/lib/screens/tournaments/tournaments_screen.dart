import 'package:flutter/material.dart';
import '../../widgets/app_drawer.dart';
import '../modals/create_tournament_modal.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/api_services.dart';

class TournamentsScreen extends StatefulWidget {
  const TournamentsScreen({super.key});

  @override
  State<TournamentsScreen> createState() => _TournamentsScreenState();
}

class _TournamentsScreenState extends State<TournamentsScreen> {
  final ApiService api = ApiService();

  bool loading = true;
  String? errorText;
  List tournaments = [];

  String? get uid => FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    _loadTournaments();
  }

  Future<void> _loadTournaments() async {
    final u = uid;
    if (u == null) return;

    setState(() {
      loading = true;
      errorText = null;
    });

    try {
      final list = await api.getCityTournaments(firebaseUid: u);
      setState(() => tournaments = list);
    } catch (e) {
      setState(() => errorText = e.toString());
    } finally {
      setState(() => loading = false);
    }
  }

  Future<void> _deleteTournament(String tournamentId) async {
    final u = uid;
    if (u == null) return;

    try {
      await api.deleteTournament(firebaseUid: u, tournamentId: tournamentId);
      await _loadTournaments();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // backgroundColor: const Color(0xFF3F3F3F),
      drawer: AppDrawer(
        userName: FirebaseAuth.instance.currentUser?.displayName ?? "User",
        photoUrl: FirebaseAuth.instance.currentUser?.photoURL,
      ),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        title: const Text(
          'Tournaments',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/splash.png',
              fit: BoxFit.cover,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const SizedBox(height: 16),

                Expanded(
                  child: loading
                      ? const Center(child: CircularProgressIndicator())
                      : (errorText != null)
                          ? Center(
                              child: Text(
                                errorText!,
                                style: const TextStyle(color: Colors.white),
                                textAlign: TextAlign.center,
                              ),
                            )
                          : tournaments.isEmpty
                              ? const Center(
                                  child: Text(
                                    "No tournaments in your city yet.",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                )
                              : ListView.separated(
                                  itemCount: tournaments.length,
                                  separatorBuilder: (_, __) => const SizedBox(height: 16),
                                  itemBuilder: (context, index) {
                                    final t = tournaments[index] as Map<String, dynamic>;

                                    final id = (t["_id"] ?? "").toString();

                                    // ✅ NEW FIELDS (from MongoDB schema)
                                    final organizerName = (t["organizerName"] ?? "").toString();
                                    final contactNo = (t["contactNo"] ?? "").toString();
                                    final entryFee = (t["entryFee"] ?? "").toString();
                                    final winningPrize = (t["winningPrize"] ?? "").toString();
                                    final venue = (t["venue"] ?? "").toString();

                                    // ✅ Show delete only for current user's tournaments
                                    final createdByUid = (t["createdByUid"] ?? "").toString();
                                    final isMine = (createdByUid.isNotEmpty && createdByUid == uid);

                                    return tournamentCard(
                                      organizerName: organizerName.isEmpty ? "Tournament" : organizerName,
                                      contactNo: contactNo,
                                      entryFee: entryFee,
                                      winningPrize: winningPrize,
                                      venue: venue,
                                      showDelete: isMine,
                                      onDelete: () => _deleteTournament(id),
                                    );
                                  },
                                ),
                ),

                const SizedBox(height: 12),

                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE5E5E5),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () async {
                      final refreshed = await showModalBottomSheet<bool>(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => const CreateTournamentModal(),
                      );

                      if (refreshed == true) {
                        _loadTournaments();
                      }
                    },
                    child: const Text(
                      'Create New Tournament',
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// ✅ UPDATED CARD: shows all tournament details
  static Widget tournamentCard({
    required String organizerName,
    required String contactNo,
    required String entryFee,
    required String winningPrize,
    required String venue,
    required bool showDelete,
    required VoidCallback onDelete,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFE5E5E5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  organizerName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 10),

                _detailRow("Contact", contactNo),
                const SizedBox(height: 6),
                _detailRow("Entry Fee", entryFee),
                const SizedBox(height: 6),
                _detailRow("Winning Prize", winningPrize),
                const SizedBox(height: 6),
                _detailRow("Venue", venue),
              ],
            ),
          ),

          if (showDelete)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.black),
              onPressed: onDelete,
            ),
        ],
      ),
    );
  }

  static Widget _detailRow(String label, String value) {
    final v = value.trim().isEmpty ? "-" : value.trim();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 90,
          child: Text(
            "$label:",
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ),
        Expanded(
          child: Text(
            v,
            style: const TextStyle(
              fontSize: 13,
              color: Colors.black54,
            ),
          ),
        ),
      ],
    );
  }
}