// AI Agent Test Drive: claims from ChatGPT and Gemini (prompts 01 and 03),
// checked against the real engine. Each test name says which agent made the
// claim and whether this calculator agrees with it.
import 'package:calculator_app/logic/calculator_engine.dart';
import 'package:flutter_test/flutter_test.dart';

import 'calculator_engine_test.dart' show press;

/// Presses [keys] one at a time and records the display after every
/// operator, `=` and `C`, e.g. `['+ 2', '× 5', '= 20']`.
List<String> trace(CalculatorEngine calc, String keys) {
  final out = <String>[];
  for (final key in keys.split(' ')) {
    press(calc, key);
    if (RegExp(r'^[+\-−×*÷/=C]$').hasMatch(key)) {
      out.add('$key ${calc.display}');
    }
  }
  return out;
}

void main() {
  late CalculatorEngine calc;
  setUp(() => calc = CalculatorEngine());

  group('Prompt 01 · Bug hunt', () {
    test('both agents: 2 + 3 × 4 = shows 2, 5, then 20 (accepted)', () {
      expect(trace(calc, '2 + 3 × 4 ='), ['+ 2', '× 5', '= 20']);
    });

    test('GPT: 10 − 3 + 2 = shows 10, 7, then 9 (accepted)', () {
      expect(trace(calc, '10 − 3 + 2 ='), ['− 10', '+ 7', '= 9']);
    });

    test('GPT: 8 + × 2 = replaces the operator and gives 16 (accepted)', () {
      expect(trace(calc, '8 + × 2 ='), ['+ 8', '× 8', '= 16']);
    });

    test('Gemini: 5 + × 2 = gives 10 (accepted)', () {
      expect(trace(calc, '5 + × 2 ='), ['+ 5', '× 5', '= 10']);
    });

    test('GPT: 5 + = is a no-op and stays 5 (accepted)', () {
      expect(trace(calc, '5 + ='), ['+ 5', '= 5']);
      expect(calc.pendingOperator, Operator.add);
    });

    test('Gemini: 2 + = defaults to 2 + 2 = 4 (REJECTED, contract ignores it)', () {
      expect(trace(calc, '2 + ='), ['+ 2', '= 2']);
      expect(calc.display, isNot('4'));
    });

    test('GPT: 2 + 3 = = stays 5 on the second equals (accepted)', () {
      expect(trace(calc, '2 + 3 = ='), ['+ 2', '= 5', '= 5']);
    });

    test('Gemini: 2 + 3 = = repeats + 3 to give 8 (REJECTED, not in contract)', () {
      press(calc, '2 + 3 = =');
      expect(calc.display, isNot('8'));
    });

    test('Gemini: 8 ÷ 0 = shows an error (accepted, needs error handling)', () {
      expect(trace(calc, '8 ÷ 0 ='), ['÷ 8', '= Can\'t divide by zero']);
      expect(calc.phase, CalcPhase.error);
    });

    test('GPT: 9 + 4 = AC 2 + 3 = shows 13, 0, then 5 (accepted)', () {
      expect(
        trace(calc, '9 + 4 = C 2 + 3 ='),
        ['+ 9', '= 13', 'C 0', '+ 2', '= 5'],
      );
    });
  });

  group('Prompt 03 · State design', () {
    test('both agents: display is derived, never stale (accepted)', () {
      // Display always matches the phase's source of truth.
      press(calc, '2 + 3');
      expect(calc.display, calc.entry);
      press(calc, '×');
      expect(calc.display, CalculatorEngine.format(calc.accumulator!));
    });

    test('GPT: after AC the accumulator is 0 (PARTLY REJECTED, it is null)', () {
      press(calc, '9 + 4 = C');
      // Stronger than GPT's suggestion: no stored total at all after AC.
      expect(calc.accumulator, isNull);
      expect(calc.display, '0');
      press(calc, '2 + 3 =');
      expect(calc.display, '5');
    });

    test('Gemini: 7 + 3 = AC + 5 = gives 5, not a stale 15 (accepted)', () {
      press(calc, '7 + 3 = C + 5 =');
      expect(calc.display, '5');
    });

    test('Gemini invariant: no pending operator → accumulator is null or '
        'equals the displayed value (accepted, holds on every step)', () {
      const sequences = [
        '2 + 3 × 4 =',
        '9 + × 2 = 5',
        '7 + = 1 = C',
        '2 + 3 × < − 1 =',
        '8 ÷ 0 = < < 2 =',
        '0.1 + 0.2 = + 1 =',
      ];
      for (final keys in sequences) {
        final c = CalculatorEngine();
        for (final key in keys.split(' ')) {
          press(c, key);
          if (c.pendingOperator == null && c.accumulator != null) {
            expect(
              CalculatorEngine.format(c.accumulator!),
              c.display,
              reason: '"$keys" broke the invariant at "$key"',
            );
          }
        }
      }
    });

    test('GPT: awaitingOperand cannot be derived from pendingOperator alone '
        '(accepted, the engine keeps an explicit phase)', () {
      press(calc, '2 +');
      expect(calc.phase, CalcPhase.awaitingOperand);
      press(calc, '3');
      // Same pending operator, different phase.
      expect(calc.pendingOperator, Operator.add);
      expect(calc.phase, CalcPhase.enteringOperand);
    });
  });
}
