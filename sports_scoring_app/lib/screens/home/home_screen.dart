import 'package:flutter/material.dart';
import 'news_screen.dart';
import 'standing_screen.dart';
import 'start_match_screen.dart';
import '../../widgets/app_drawer.dart';
import 'package:firebase_auth/firebase_auth.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int selectedTab = 0;

  final List<Widget> screens = const [
    NewsScreen(),
    StandingsScreen(
  // leagueId: 39,        // Premier League
  // season: 2024,
),
    StartMatchScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      /// ✅ Drawer
      drawer: AppDrawer(
  userName: FirebaseAuth.instance.currentUser?.displayName ?? "User",
  photoUrl: FirebaseAuth.instance.currentUser?.photoURL,
),


      /// ✅ Transparent AppBar with centered title
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Home',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w600,
            fontSize: 22,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.black),
      ),

      body: Stack(
        children: [
          /// 🔴 Background brush
          Positioned.fill(
            child: Image.asset(
              'assets/images/splash.png',
              fit: BoxFit.cover,
            ),
          ),

          /// Content
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 10),


                /// 🔘 Tabs
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    tabButton("News", 0),
                    tabButton("Standings", 1),
                    tabButton("Start a Match", 2),
                  ],
                ),

                const SizedBox(height: 16),

                /// 🔽 Screen content
                Expanded(child: screens[selectedTab]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget tabButton(String title, int index) {
    final bool active = selectedTab == index;

    return GestureDetector(
      onTap: () => setState(() => selectedTab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: active ? const Color(0xFFE5E5E5) : const Color(0xFF2F2F2F),
          borderRadius: BorderRadius.circular(20),
          boxShadow: active
              ? []
              : const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 6,
                    offset: Offset(0, 3),
                  )
                ],
        ),
        child: Text(
          title,
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
