import 'package:flutter/material.dart';

import '../logic/calculator_engine.dart';
import '../widgets/display_panel.dart';
import '../widgets/history_sheet.dart';
import '../widgets/keypad.dart';

/// Owns the single [CalculatorEngine]. Every key goes through [_run], so all
/// UI updates come from engine state via one `setState()` call.
class CalculatorScreen extends StatefulWidget {
  const CalculatorScreen({super.key});

  @override
  State<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen> {
  final CalculatorEngine _engine = CalculatorEngine();
  bool _showTape = false;

  void _run(void Function(CalculatorEngine engine) action) {
    setState(() => action(_engine));
  }

  void _openHistory() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => HistorySheet(
        entries: _engine.history.reversed.toList(),
        onRecall: (item) => _run((e) => e.recall(item)),
        onClear: _clearHistory,
      ),
    );
  }

  void _clearHistory() {
    late final List<HistoryEntry> removed;
    setState(() => removed = _engine.clearHistory());
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text('Cleared ${removed.length} '
            '${removed.length == 1 ? 'calculation' : 'calculations'}'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => setState(() => _engine.restoreHistory(removed)),
        ),
      ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Expanded(
                flex: 2,
                child: DisplayPanel(
                  engine: _engine,
                  showTape: _showTape,
                  onToggleTape: () => setState(() => _showTape = !_showTape),
                  onOpenHistory: _openHistory,
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                flex: 3,
                child: Keypad(
                  pendingOperator: _engine.phase == CalcPhase.awaitingOperand
                      ? _engine.pendingOperator
                      : null,
                  onDigit: (d) => _run((e) => e.inputDigit(d)),
                  onDecimal: () => _run((e) => e.inputDecimal()),
                  onOperator: (op) => _run((e) => e.chooseOperator(op)),
                  onEquals: () => _run((e) => e.equals()),
                  onAllClear: () => _run((e) => e.allClear()),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
