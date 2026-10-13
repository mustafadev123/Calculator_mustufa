import 'package:calculator_app/logic/calculator_engine.dart';
import 'package:flutter_test/flutter_test.dart';

/// Simulates key presses on [engine]. Accepts digits, `.`, `+ − - × * ÷ /`,
/// `=` and `C` (for AC). Spaces are ignored so traces stay readable.
void press(CalculatorEngine engine, String keys) {
  for (final key in keys.split('')) {
    switch (key) {
      case ' ':
        break;
      case '.':
        engine.inputDecimal();
      case '+':
        engine.chooseOperator(Operator.add);
      case '-' || '−':
        engine.chooseOperator(Operator.subtract);
      case '*' || '×':
        engine.chooseOperator(Operator.multiply);
      case '/' || '÷':
        engine.chooseOperator(Operator.divide);
      case '=':
        engine.equals();
      case 'C':
        engine.allClear();
      default:
        engine.inputDigit(int.parse(key));
    }
  }
}

void main() {
  late CalculatorEngine calc;

  setUp(() => calc = CalculatorEngine());

  group('Core state contract', () {
    test('starts in ready phase showing 0', () {
      expect(calc.phase, CalcPhase.ready);
      expect(calc.display, '0');
      expect(calc.expression, '');
    });

    test('2 + 3 stores 2 and +, second operand shows 3', () {
      press(calc, '2 + 3');
      expect(calc.accumulator, 2);
      expect(calc.pendingOperator, Operator.add);
      expect(calc.display, '3');
      expect(calc.expression, '2 +');
    });

    test('× after 2 + 3 applies pending op and shows running total 5', () {
      press(calc, '2 + 3 ×');
      expect(calc.display, '5');
      expect(calc.accumulator, 5);
      expect(calc.phase, CalcPhase.awaitingOperand);
      expect(calc.lastTransition!.note, 'apply 2 + 3 = 5');
    });

    test('2 + 3 × 4 = evaluates left to right to 20 (not 14)', () {
      press(calc, '2 + 3 × 4 =');
      expect(calc.display, '20');
      expect(calc.phase, CalcPhase.result);
      expect(calc.expression, '5 × 4 =');
    });

    test('9 + × 2 = replaces + with × and gives 18', () {
      press(calc, '9 + ×');
      expect(calc.pendingOperator, Operator.multiply);
      expect(calc.lastTransition!.note, 'replace + with ×');
      press(calc, '2 =');
      expect(calc.display, '18');
    });

    test('7 + = ignores equals and keeps the pending operation', () {
      press(calc, '7 + =');
      expect(calc.display, '7');
      expect(calc.phase, CalcPhase.awaitingOperand);
      expect(calc.pendingOperator, Operator.add);
      expect(calc.lastTransition!.note, 'ignored: awaiting operand');
      press(calc, '1 =');
      expect(calc.display, '8');
    });

    test('digit after equals starts a fresh calculation', () {
      press(calc, '4 + 4 =');
      expect(calc.display, '8');
      press(calc, '6');
      expect(calc.display, '6');
      expect(calc.accumulator, isNull);
      expect(calc.pendingOperator, isNull);
      expect(calc.lastTransition!.note, 'fresh calculation');
    });

    test('operator after equals continues from the result', () {
      press(calc, '4 + 4 = − 3 =');
      expect(calc.display, '5');
    });

    test('AC clears operand, accumulator, pending operator and result', () {
      press(calc, '8 × 3 + 1');
      press(calc, 'C');
      expect(calc.display, '0');
      expect(calc.accumulator, isNull);
      expect(calc.pendingOperator, isNull);
      expect(calc.phase, CalcPhase.ready);
      expect(calc.expression, '');
    });

    test('no stale accumulator after AC', () {
      press(calc, '5 + C 2 + 3 =');
      expect(calc.display, '5');
    });

    test('chains all four operations left to right', () {
      // ((((10 + 5) − 3) × 4) ÷ 6) = 8
      press(calc, '10 + 5 − 3 × 4 ÷ 6 =');
      expect(calc.display, '8');
    });

    test('equals with nothing pending is ignored', () {
      press(calc, '42 =');
      expect(calc.display, '42');
      expect(calc.phase, CalcPhase.enteringOperand);
    });

    test('leading zero is replaced, not appended', () {
      press(calc, '0 0 7');
      expect(calc.display, '7');
    });

    test('operand stops growing at the digit limit', () {
      press(calc, '1' * 20);
      expect(calc.display, '1' * CalculatorEngine.maxDigits);
    });
  });

  group('Decimal support (graduate)', () {
    test('decimal addition: 0.1 + 0.2 = 0.3', () {
      press(calc, '0.1 + 0.2 =');
      expect(calc.display, '0.3');
    });

    test('decimal subtraction: 5.5 − 2.25 = 3.25', () {
      press(calc, '5.5 − 2.25 =');
      expect(calc.display, '3.25');
    });

    test('decimal multiplication: 1.5 × 1.5 = 2.25', () {
      press(calc, '1.5 × 1.5 =');
      expect(calc.display, '2.25');
    });

    test('decimal division: 7.5 ÷ 2.5 = 3', () {
      press(calc, '7.5 ÷ 2.5 =');
      expect(calc.display, '3');
    });

    test('non-terminating division is rounded for display: 1 ÷ 3', () {
      press(calc, '1 ÷ 3 =');
      expect(calc.display, '0.333333333333');
    });

    test('a second decimal point is rejected', () {
      press(calc, '3.1.4');
      expect(calc.display, '3.14');
    });

    test('point first starts the operand at 0.', () {
      press(calc, '.5');
      expect(calc.display, '0.5');
      press(calc, '+ .');
      expect(calc.display, '0.');
    });

    test('trailing point is accepted as a whole number: 4. + 1 = 5', () {
      press(calc, '4. + 1 =');
      expect(calc.display, '5');
    });

    test('point after equals starts a fresh calculation', () {
      press(calc, '2 + 2 = .7');
      expect(calc.display, '0.7');
      expect(calc.accumulator, isNull);
    });
  });

  group('Errors', () {
    test('division by zero shows a message and digit recovers', () {
      press(calc, '8 ÷ 0 =');
      expect(calc.phase, CalcPhase.error);
      expect(calc.display, 'Can\'t divide by zero');
      press(calc, '3');
      expect(calc.phase, CalcPhase.enteringOperand);
      expect(calc.display, '3');
    });

    test('division by zero mid-chain is caught on the next operator', () {
      press(calc, '8 ÷ 0 +');
      expect(calc.phase, CalcPhase.error);
    });

    test('operators are ignored while in error', () {
      press(calc, '1 ÷ 0 = +');
      expect(calc.phase, CalcPhase.error);
    });
  });

  group('Transition tape', () {
    test('records each key with from/to phases', () {
      press(calc, '2 +');
      expect(calc.tape, hasLength(2));
      expect(calc.tape[0].from, CalcPhase.ready);
      expect(calc.tape[0].to, CalcPhase.enteringOperand);
      expect(calc.tape[1].to, CalcPhase.awaitingOperand);
    });

    test('keeps only the most recent entries', () {
      press(calc, '1' * (CalculatorEngine.tapeLength + 10));
      expect(calc.tape, hasLength(CalculatorEngine.tapeLength));
    });
  });

  group('format()', () {
    test('drops .0 and floating-point noise', () {
      expect(CalculatorEngine.format(20.0), '20');
      expect(CalculatorEngine.format(-0.0), '0');
      expect(CalculatorEngine.format(2.9999999999999996), '3');
    });

    test('uses exponent form for very large and small values', () {
      expect(CalculatorEngine.format(1e20), '1e+20');
      expect(CalculatorEngine.format(1.5e-9), '1.5e-9');
    });
  });
}
