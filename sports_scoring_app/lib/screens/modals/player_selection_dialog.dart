import 'package:flutter/material.dart';
import '../../models/teams.dart';

class PlayerSelectionDialog extends StatefulWidget {
  final Team? battingTeam;
  final Team? bowlingTeam;
  final bool batsmanOnly;
  final bool bowlerOnly;

  final Function(String?, String?, String?) onConfirm;

  const PlayerSelectionDialog({
    super.key,
    this.battingTeam,
    this.bowlingTeam,
    this.batsmanOnly = false,
    this.bowlerOnly = false,
    required this.onConfirm,
  });

  @override
  State<PlayerSelectionDialog> createState() =>
      _PlayerSelectionDialogState();
}

class _PlayerSelectionDialogState extends State<PlayerSelectionDialog> {
  String? striker;
  String? nonStriker;
  String? bowler;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select Players'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!widget.bowlerOnly)
            DropdownButtonFormField<String>(
              hint: const Text('Striker'),
              items: widget.battingTeam!.players
                  .map((p) =>
                      DropdownMenuItem(value: p, child: Text(p)))
                  .toList(),
              onChanged: (v) => striker = v,
            ),

          if (!widget.bowlerOnly && !widget.batsmanOnly)
            DropdownButtonFormField<String>(
              hint: const Text('Non-Striker'),
              items: widget.battingTeam!.players
                  .map((p) =>
                      DropdownMenuItem(value: p, child: Text(p)))
                  .toList(),
              onChanged: (v) => nonStriker = v,
            ),

          if (!widget.batsmanOnly)
            DropdownButtonFormField<String>(
              hint: const Text('Bowler'),
              items: widget.bowlingTeam!.players
                  .map((p) =>
                      DropdownMenuItem(value: p, child: Text(p)))
                  .toList(),
              onChanged: (v) => bowler = v,
            ),
        ],
      ),
      actions: [
        ElevatedButton(
          onPressed: () {
            widget.onConfirm(striker, nonStriker, bowler);
            Navigator.pop(context);
          },
          child: const Text('Confirm'),
        ),
      ],
    );
  }
}
