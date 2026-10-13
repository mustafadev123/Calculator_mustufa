# Calculator State Lab

A Flutter calculator for **CSC 6370 · Assignment 01** that evaluates left to right
with a visible running total, so `2 + 3 × 4 =` is `(2 + 3) × 4 = 20`.

**Author:** Muhammad Mustufa · 00300444 · Graduate pathway

## Features

| Feature | What it does |
|---|---|
| **Core** | Digits 0–9, `+ − × ÷`, `=`, AC. Each operator applies the pending one first and shows the running total. A second operator replaces the first; `=` with no new number is ignored; a digit after `=` starts fresh. |
| **Decimal support** (required) | Decimal input and results for all four operations, one point per number, floating-point noise trimmed (`0.1 + 0.2` shows `0.3`). |
| **Calculation history** | Scrollable list of finished calculations with their full chain (`2 + 3 × 4 = 20`). Tap an entry to reuse its result; Clear with Undo. |
| **Backspace / delete** | ⌫ deletes the last character, steps back over an operator, and removes reused values whole. Hold ⌫ to clear everything. Refused presses shake the display. |
| **Advanced error handling** | Division by zero, overflow (±1e100), underflow (below 1e-100) and invalid numbers each show a clear message and a recovery hint. ⌫ on an error returns to just before the failing step. |

Extras: a **state chip** showing the current phase (READY, ENTER, AWAIT, RESULT, ERROR),
a **state tape** that logs every key press with its before/after state, light/dark
theme from the system setting, and screen-reader labels on every control.

## Run it

Requires the Flutter SDK (tested on Flutter 3.47.4, Dart 3.13.3).

```bash
git clone https://github.com/mustafadev123/Calculator_mustufa.git
cd Calculator_mustufa
flutter pub get
flutter run              # Android emulator/device
flutter run -d chrome    # or in the browser
```

## Test it

```bash
flutter test
```

107 tests, all passing:

- `test/calculator_engine_test.dart`: every core rule, decimals, history, backspace, errors and input checks
- `test/widget_test.dart`: tapping through the real UI, small-screen layout (320×568), screen-reader labels
- `test/ai_claims_test.dart`: claims from ChatGPT and Gemini checked against the app

## Build the APK

```bash
flutter build apk
```

Output: `build/app/outputs/flutter-apk/app-release.apk`

## Project layout

```
lib/
  main.dart                  App entry point and theme setup
  theme.dart                 Colors and labels for each phase
  logic/
    calculator_engine.dart   All calculator rules (plain Dart, no UI)
    calc_error.dart          Error types with messages and hints
  screens/
    calculator_screen.dart   Holds the engine; every key goes through one setState()
  widgets/
    display_panel.dart       Phase chip, hint line, expression and total
    keypad.dart              Button grid
    calc_button.dart         One key: ripple, haptics, screen-reader label
    history_sheet.dart       History bottom sheet
    state_tape.dart          Transition log
    shake.dart               Shake animation for refused input
```
