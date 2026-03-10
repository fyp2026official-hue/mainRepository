import 'package:flutter/material.dart';
import '../../models/teams.dart';

class BowlerSelectionDialog extends StatefulWidget {
  final Team bowlingTeam;
  final Function(String bowler) onConfirm;

  const BowlerSelectionDialog({
    super.key,
    required this.bowlingTeam,
    required this.onConfirm,
  });

  @override
  State<BowlerSelectionDialog> createState() =>
      _BowlerSelectionDialogState();
}

class _BowlerSelectionDialogState extends State<BowlerSelectionDialog> {
  String? selectedBowler;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select Bowler'),
      content: DropdownButtonFormField<String>(
        value: selectedBowler,
        hint: const Text('Choose bowler'),
        items: widget.bowlingTeam.players
            .map(
              (p) => DropdownMenuItem(
                value: p,
                child: Text(p),
              ),
            )
            .toList(),
        onChanged: (v) => setState(() => selectedBowler = v),
      ),
      actions: [
        TextButton(
          onPressed: selectedBowler == null
              ? null
              : () {
                  widget.onConfirm(selectedBowler!);
                  Navigator.pop(context);
                },
          child: const Text('Confirm'),
        ),
      ],
    );
  }
}
