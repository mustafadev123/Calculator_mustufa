import 'package:flutter/material.dart';

import 'logic/calculator_engine.dart';

/// Material 3 theme seeded from a deep "lab" teal. Light and dark follow the
/// system setting; every calculator surface reads its colors from here.
ThemeData buildLabTheme(Brightness brightness) {
  final scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF00897B),
    brightness: brightness,
  );
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    scaffoldBackgroundColor: scheme.surface,
  );
}

/// Short labels and accent colors for each phase, used by the phase chip and
/// the state tape.
extension PhaseStyle on CalcPhase {
  String get label => switch (this) {
    CalcPhase.ready => 'READY',
    CalcPhase.enteringOperand => 'ENTER',
    CalcPhase.awaitingOperand => 'AWAIT',
    CalcPhase.result => 'RESULT',
    CalcPhase.error => 'ERROR',
  };

  /// Spoken form for screen readers.
  String get spoken => switch (this) {
    CalcPhase.ready => 'ready',
    CalcPhase.enteringOperand => 'entering number',
    CalcPhase.awaitingOperand => 'waiting for next number',
    CalcPhase.result => 'result',
    CalcPhase.error => 'error',
  };

  Color color(ColorScheme scheme) => switch (this) {
    CalcPhase.ready => scheme.outline,
    CalcPhase.enteringOperand => scheme.primary,
    CalcPhase.awaitingOperand => scheme.tertiary,
    CalcPhase.result => scheme.secondary,
    CalcPhase.error => scheme.error,
  };
}
