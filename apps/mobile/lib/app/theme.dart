import 'package:flutter/material.dart';

/// [foundations.md §2](../../../../docs/10-design-system/foundations.md)'s real seed colour —
/// deliberately muted, since a POS glanced at for eight hours a day is not the
/// place for a saturated brand colour. Wired in for Sprint 06, the first real
/// screen (login) to actually be themed rather than left at the scaffold's
/// placeholder indigo.
const _seedColor = Color(0xFF0F6B5C);

ThemeData buildAppTheme({Brightness brightness = Brightness.light}) {
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: ColorScheme.fromSeed(
      seedColor: _seedColor,
      brightness: brightness,
    ),
  );
}
