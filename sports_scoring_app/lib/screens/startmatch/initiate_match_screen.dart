import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../../models/match_data.dart';
import '../score/score_screen.dart';

class InitiatMatchScreen extends StatefulWidget {
  final MatchData matchData;

  const InitiatMatchScreen({
    super.key,
    required this.matchData,
  });

  @override
  State<InitiatMatchScreen> createState() => _InitiatMatchScreenState();
}

class _InitiatMatchScreenState extends State<InitiatMatchScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0, // 👈 START INVISIBLE
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeIn,
      ),
    );

    // ⏳ DELAY so user can see the fade
    Future.delayed(const Duration(milliseconds: 300), () {
      _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Column(
            children: [
              const SizedBox(height: 80),

              /// 🔥 TITLE (FADE IN)
              FadeTransition(
                opacity: _fadeAnimation,
                child: const Text(
                  "Let's Go!",
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ),

              const SizedBox(height: 120),

              /// 🎾 LOTTIE (STATIC)
              Center(
                child: Lottie.asset(
                  'assets/animations/ball.json',
                  height: MediaQuery.of(context).size.height * 0.3,
                ),
              ),

              const Spacer(),

              /// 👉 CONTINUE BUTTON (FADE IN)
              FadeTransition(
                opacity: _fadeAnimation,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE5E5E5),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ScoreScreen(
                              matchData: widget.matchData,
                            ),
                          ),
                        );
                      },
                      child: const Text(
                        'Continue',
                        style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ],
      ),
    );
  }
}
