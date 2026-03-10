import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:http/http.dart' as http;

class NewsScreen extends StatefulWidget {
  const NewsScreen({super.key});

  @override
  State<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends State<NewsScreen> {
  final String baseUrl = "http://192.168.10.9:5000";

  bool loading = false;
  String? errorText;
  DateTime selectedDate = DateTime.now().subtract(const Duration(days: 1));
  List news = [];

  // ✅ horizontal auto-scroll
  final PageController _pageController = PageController(viewportFraction: 0.88);
  Timer? _autoTimer;
  int _currentIndex = 0;

  // ✅ card height control
  static const double _cardHeight = 240;

  String _fmtYmd(DateTime d) {
    String two(int n) => n.toString().padLeft(2, "0");
    return "${d.year}-${two(d.month)}-${two(d.day)}";
  }

  void _stopAutoScroll() {
    _autoTimer?.cancel();
    _autoTimer = null;
  }

  void _startAutoScroll() {
    _stopAutoScroll();
    if (news.isEmpty) return;

    _autoTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || news.isEmpty) return;

      final next = (_currentIndex + 1) % news.length;
      _currentIndex = next;

      _pageController.animateToPage(
        next,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOut,
      );
    });
  }

  Future<void> _fetchPremiumNews() async {
    setState(() {
      loading = true;
      errorText = null;
      news = [];
      _currentIndex = 0;
    });

    _stopAutoScroll();

    try {
      final uri = Uri.parse("$baseUrl/news/premium?date=${_fmtYmd(selectedDate)}");
      final res = await http.get(uri);

      if (res.statusCode != 200) {
        throw Exception("HTTP ${res.statusCode}: ${res.body}");
      }

      final data = jsonDecode(res.body);
      final list = (data["response"] is List) ? List.from(data["response"]) : [];

      setState(() {
        news = list;
        loading = false;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (news.isNotEmpty) {
          _pageController.jumpToPage(0);
          _startAutoScroll();
        }
      });
    } catch (e) {
      setState(() {
        loading = false;
        errorText = e.toString();
        news = [];
      });
    }
  }

  Future<void> _pickDateAndFetch() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(DateTime.now().year - 2),
      lastDate: DateTime(DateTime.now().year + 2),
    );

    if (picked == null) return;

    setState(() => selectedDate = picked);
    await _fetchPremiumNews();
  }

  Widget _dateButton() {
    final label = "Select Date: ${_fmtYmd(selectedDate)}";

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _pickDateAndFetch,
        icon: const Icon(Icons.calendar_month),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  // ✅ Heading for NBA news
  Widget _nbaHeading() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: const Text(
        "NBA News",
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: Colors.black,
        ),
      ),
    );
  }

  Widget _newsCard(dynamic item) {
    final title = (item["Title"] ?? "News").toString();
    final content = (item["Content"] ?? "").toString();
    final timeAgo = (item["TimeAgo"] ?? "").toString();
    final updated = (item["Updated"] ?? "").toString();
    final source = (item["Source"] ?? "").toString();

    String subtitleLine = "";
    if (timeAgo.trim().isNotEmpty) subtitleLine = timeAgo;
    else if (updated.trim().isNotEmpty) subtitleLine = updated;

    final preview = content.trim().isEmpty ? "No details available." : content.trim();

    return SizedBox(
      height: _cardHeight, // ✅ fixed card height
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFE5E5E5),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 6),

            if (subtitleLine.isNotEmpty || source.isNotEmpty)
              Text(
                [
                  if (source.isNotEmpty) source,
                  if (subtitleLine.isNotEmpty) subtitleLine,
                ].join(" • "),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.black54,
                ),
              ),

            const SizedBox(height: 12),

            Expanded(
              child: Text(
                preview,
                maxLines: 6,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black87,
                  height: 1.3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _fetchPremiumNews();
  }

  @override
  void dispose() {
    _stopAutoScroll();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          const SizedBox(height: 8),
          _dateButton(),
          const SizedBox(height: 10),

          // ✅ NBA heading
          _nbaHeading(),
          const SizedBox(height: 8),

          // ✅ horizontal cards area with controlled height
          SizedBox(
            height: _cardHeight + 14, // a little extra for margins
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : errorText != null
                    ? Center(
                        child: Text(
                          "Error:\n$errorText",
                          textAlign: TextAlign.center,
                        ),
                      )
                    : news.isEmpty
                        ? const Center(child: Text("No news found for this date"))
                        : NotificationListener<UserScrollNotification>(
                            onNotification: (n) {
                              if (n.direction != ScrollDirection.idle) {
                                _stopAutoScroll();
                              } else {
                                _startAutoScroll();
                              }
                              return false;
                            },
                            child: PageView.builder(
                              controller: _pageController,
                              itemCount: news.length,
                              onPageChanged: (i) => _currentIndex = i,
                              itemBuilder: (context, i) => _newsCard(news[i]),
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}