import 'package:flutter/material.dart';

class Team {
  /// Team name (string value)
  String name;

  /// Controllers (used only in UI)
  final TextEditingController teamNameCtrl;
  final TextEditingController playerCtrl;

  /// Players list
  final List<String> players;

  Team({
    this.name = '',
    TextEditingController? teamNameCtrl,
    TextEditingController? playerCtrl,
    List<String>? players,
  })  : teamNameCtrl = teamNameCtrl ?? TextEditingController(),
        playerCtrl = playerCtrl ?? TextEditingController(),
        players = players ?? [];
}
