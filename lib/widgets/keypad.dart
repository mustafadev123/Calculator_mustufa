import 'package:flutter/material.dart';

import '../logic/calculator_engine.dart';
import 'calc_button.dart';

/// 4-column button grid. Rows are [Expanded] so the pad fills whatever height
/// it gets, from a small phone to a tablet.
class Keypad extends StatelessWidget {
  const Keypad({
    super.key,
    required this.pendingOperator,
    required this.onDigit,
    required this.onDecimal,
    required this.onOperator,
    required this.onEquals,
    required this.onAllClear,
    required this.onBackspace,
    required this.onBackspaceHold,
  });

  /// Shown as selected while waiting for the next operand.
  final Operator? pendingOperator;
  final ValueChanged<int> onDigit;
  final VoidCallback onDecimal;
  final ValueChanged<Operator> onOperator;
  final VoidCallback onEquals;
  final VoidCallback onAllClear;
  final VoidCallback onBackspace;
  final VoidCallback onBackspaceHold;

  static const _spoken = {
    Operator.add: 'plus',
    Operator.subtract: 'minus',
    Operator.multiply: 'multiply',
    Operator.divide: 'divide',
  };

  Widget _digit(int d, {int flex = 1}) => CalcButton(
        key: Key('key_$d'),
        label: '$d',
        semanticLabel: '$d',
        flex: flex,
        onPressed: () => onDigit(d),
      );

  Widget _operator(Operator op) => CalcButton(
        key: Key('key_${op.name}'),
        label: op.symbol,
        semanticLabel: _spoken[op]!,
        kind: CalcButtonKind.operator,
        selected: pendingOperator == op,
        onPressed: () => onOperator(op),
      );

  Widget _row(List<Widget> children) =>
      Expanded(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: children));

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _row([
          CalcButton(
            key: const Key('key_ac'),
            label: 'AC',
            semanticLabel: 'all clear',
            kind: CalcButtonKind.action,
            flex: 2,
            onPressed: onAllClear,
          ),
          CalcButton(
            key: const Key('key_backspace'),
            label: '⌫',
            icon: Icons.backspace_outlined,
            semanticLabel: 'delete',
            semanticHint: 'hold to clear all',
            kind: CalcButtonKind.action,
            onPressed: onBackspace,
            onLongPress: onBackspaceHold,
          ),
          _operator(Operator.divide),
        ]),
        _row([_digit(7), _digit(8), _digit(9), _operator(Operator.multiply)]),
        _row([_digit(4), _digit(5), _digit(6), _operator(Operator.subtract)]),
        _row([_digit(1), _digit(2), _digit(3), _operator(Operator.add)]),
        _row([
          _digit(0, flex: 2),
          CalcButton(
            key: const Key('key_decimal'),
            label: '.',
            semanticLabel: 'decimal point',
            onPressed: onDecimal,
          ),
          CalcButton(
            key: const Key('key_equals'),
            label: '=',
            semanticLabel: 'equals',
            kind: CalcButtonKind.equals,
            onPressed: onEquals,
          ),
        ]),
      ],
    );
  }
}
