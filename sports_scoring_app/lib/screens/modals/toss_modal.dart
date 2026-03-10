import 'package:flutter/material.dart';
import '../../models/teams.dart';

class TossModal extends StatefulWidget {
  final List<Team> teams;
  const TossModal({super.key, required this.teams});

  @override
  State<TossModal> createState() => _TossModalState();
}

class _TossModalState extends State<TossModal> {
  String? selectedTeam;
  String? decision; // Bat / Bowl

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          /// Header with close icon
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Toss",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),

          const SizedBox(height: 12),

          /// Team dropdown
          DropdownButtonFormField<String>(
            value: selectedTeam,
            hint: const Text("Select Team"),
            items: widget.teams.map((t) {
              return DropdownMenuItem<String>(
                value: t.name,
                child: Text(t.name.isEmpty ? "Unnamed Team" : t.name),
              );
            }).toList(),
            onChanged: (v) => setState(() => selectedTeam = v),
          ),

          const SizedBox(height: 16),

          /// Bat / Bowl
          Row(
            children: [
              Expanded(child: choiceButton("Bat")),
              const SizedBox(width: 12),
              Expanded(child: choiceButton("Bowl")),
            ],
          ),

          const SizedBox(height: 20),

          /// OK button
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton(
              onPressed: selectedTeam == null || decision == null
                  ? null
                  : () {
                      /// ✅ RETURN NON-NULL STRINGS ONLY
                      Navigator.pop<Map<String, String>>(context, {
                        'winner': selectedTeam!,
                        'decision': decision!,
                      });
                    },
              child: const Text("OK"),
            ),
          ),
        ],
      ),
    );
  }

  Widget choiceButton(String text) {
    final active = decision == text;
    return GestureDetector(
      onTap: () => setState(() => decision = text),
      child: Container(
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? Colors.green : Colors.grey.shade300,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: active ? Colors.white : Colors.black,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
