import 'package:flutter/material.dart';

/// Placeholder Material 3 theme — docs/10-design-system/foundations.md's
/// actual design tokens are wired in once a real screen consumes them; there
/// is nothing to theme yet beyond the walking-skeleton home screen.
ThemeData buildAppTheme() {
  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
  );
}
