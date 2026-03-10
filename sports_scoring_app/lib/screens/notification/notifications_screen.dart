import 'package:flutter/material.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          /// 🔴 Background Image
          Positioned.fill(
            child: Image.asset(
              'assets/images/splash.png',
              fit: BoxFit.cover,
            ),
          ),

          /// 🧾 Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 40),

                /// HEADER
                Row(
                  children: const [
                    Icon(Icons.notifications, color: Colors.black),
                    SizedBox(width: 8),
                    Text(
                      'Notifications',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                /// TODAY
                sectionTitle('Today'),
                const SizedBox(height: 10),

                notificationCard(
                  title: 'Test Location',
                  subtitle: 'Location details',
                ),
                notificationCard(
                  title: 'Test Location',
                  subtitle: 'Location details',
                ),
                notificationCard(
                  title: 'Test Location',
                  subtitle: 'Location details',
                ),

                const SizedBox(height: 20),

                /// YESTERDAY
                sectionTitle('Yesterday'),
                const SizedBox(height: 10),

                notificationCard(
                  title: 'Test Location',
                  subtitle: 'Location details',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 🔹 Section Title
  Widget sectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: Colors.black,
      ),
    );
  }

  /// 🔹 Notification Card
  Widget notificationCard({
    required String title,
    required String subtitle,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFE5E5E5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
