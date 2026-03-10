import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

// 👉 Import your screens
import '../screens/home/home_screen.dart';
import '../screens/tournaments/tournaments_screen.dart';
import '../screens/history/match_history_screen.dart';
import '../screens/welcome/welcome_screen.dart';

class AppDrawer extends StatefulWidget {
  final String userName;
  final String? photoUrl;

  const AppDrawer({
    super.key,
    required this.userName,
    required this.photoUrl,
  });

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  bool notificationsEnabled = true;
  bool loadingNotificationSetting = false;

  @override
  void initState() {
    super.initState();
    _loadNotificationSetting();
  }

  Future<void> _loadNotificationSetting() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final token = await user.getIdToken(true);

      final response = await http.get(
        Uri.parse("http://192.168.10.9:5000/api/users/me"),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final userData = data["user"];
        final bool savedValue = userData["notificationsEnabled"] ?? true;

        if (!mounted) return;
        setState(() {
          notificationsEnabled = savedValue;
        });
      }
    } catch (e) {
      debugPrint("Load notification setting error: $e");
    }
  }

  Future<void> _updateNotificationSetting(bool value) async {
    setState(() {
      loadingNotificationSetting = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final token = await user.getIdToken(true);

      final response = await http.put(
        Uri.parse("http://192.168.10.9:5000/api/users/me/notifications"),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "notificationsEnabled": value,
        }),
      );

      if (response.statusCode == 200) {
        if (!mounted) return;
        setState(() {
          notificationsEnabled = value;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              value
                  ? "Notifications turned on"
                  : "Notifications turned off",
            ),
          ),
        );
      } else {
        throw Exception("Failed to update setting: ${response.body}");
      }
    } catch (e) {
      debugPrint("Update notification setting error: $e");

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to update notifications: $e")),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        loadingNotificationSetting = false;
      });
    }
  }

  Future<void> _logout(BuildContext context) async {
    try {
      await FirebaseAuth.instance.signOut();

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const WelcomeScreen()),
        (_) => false,
      );
    } catch (e) {
      debugPrint("Logout error: $e");
    }
  }

  void _navigate(Widget screen) {
    Navigator.pop(context);
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: const Color(0xFFBDBDBD),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DrawerHeader(
            margin: EdgeInsets.zero,
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFFBDBDBD),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.orange,
                  backgroundImage: widget.photoUrl != null
                      ? NetworkImage(widget.photoUrl!)
                      : null,
                  child: widget.photoUrl == null
                      ? const Icon(Icons.person, color: Colors.white, size: 30)
                      : null,
                ),
                const SizedBox(width: 12),
                Text(
                  widget.userName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          _drawerItem(
            icon: Icons.home,
            title: 'Home',
            onTap: () => _navigate(const HomeScreen()),
          ),

          _drawerItem(
            icon: Icons.play_arrow,
            title: 'Tournaments',
            onTap: () => _navigate(const TournamentsScreen()),
          ),

          _drawerItem(
            icon: Icons.history,
            title: 'Previous Matches',
            onTap: () => _navigate(const MatchHistoryScreen()),
          ),

          SwitchListTile(
            secondary: const Icon(Icons.notifications, color: Colors.black),
            title: const Text('Notifications'),
            value: notificationsEnabled,
            activeColor: Colors.green,
            onChanged: loadingNotificationSetting
                ? null
                : (value) async {
                    await _updateNotificationSetting(value);
                  },
          ),

          const Spacer(),

          _drawerItem(
            icon: Icons.logout,
            title: 'Logout',
            onTap: () => _logout(context),
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _drawerItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.black),
      title: Text(title, style: const TextStyle(fontSize: 16)),
      onTap: onTap,
    );
  }
}