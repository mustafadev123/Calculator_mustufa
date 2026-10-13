/// Core state machine for the left-to-right running-total calculator.
///
/// The engine is plain Dart (no Flutter imports) so every transition can be
/// unit-tested without pumping widgets. The UI owns one engine instance and
/// calls these methods inside `setState()`.
///
/// Evaluation rule: no operator precedence. Each operator applies the pending
/// operation first, so `2 + 3 × 4 =` is `(2 + 3) × 4 = 20`.
library;

import 'calc_error.dart';

export 'calc_error.dart';

/// The four arithmetic operators, with the glyph shown on screen.
enum Operator {
  add('+'),
  subtract('−'),
  multiply('×'),
  divide('÷');

  const Operator(this.symbol);
  final String symbol;
}

/// Every state the calculator can be in. The display is derived from the
/// phase, so there is never a second copy of "what's on screen" to go stale.
enum CalcPhase {
  /// Fresh start: display shows 0, nothing stored.
  ready,

  /// The user is typing digits into [CalculatorEngine.entry].
  enteringOperand,

  /// An operator was chosen; the next digit starts a new operand.
  awaitingOperand,

  /// Equals finished a calculation; a digit starts over.
  result,

  /// A step failed (see [CalcError]). ⌫ goes back to just before the failing
  /// step; a digit starts over; AC resets.
  error,
}

/// One recorded step: what was pressed, how the phase moved, and why.
class Transition {
  const Transition({
    required this.input,
    required this.from,
    required this.to,
    required this.display,
    required this.note,
    this.rejected = false,
  });

  final String input;
  final CalcPhase from;
  final CalcPhase to;
  final String display;
  final String note;

  /// True when the input was refused and nothing changed.
  final bool rejected;

  @override
  String toString() => '$input: ${from.name} → ${to.name} [$display] $note';
}

/// Everything needed to step back out of an error.
typedef _Snapshot = ({
  double? accumulator,
  String entry,
  Operator? pending,
  CalcPhase phase,
  String lastExpression,
  String chain,
  bool entryRecalled,
});

/// A finished calculation, e.g. `2 + 3 × 4` → `20`.
class HistoryEntry {
  const HistoryEntry({required this.chain, required this.result});

  /// The full left-to-right chain that was evaluated, without `=`.
  final String chain;
  final double result;

  @override
  String toString() => '$chain = ${CalculatorEngine.format(result)}';
}

class CalculatorEngine {
  /// Longest operand we accept, counting digits only.
  static const int maxDigits = 15;

  /// How many transitions the tape keeps before dropping the oldest.
  static const int tapeLength = 50;

  /// How many finished calculations history keeps.
  static const int historyLength = 100;

  /// Results at or beyond this size are reported as overflow.
  static const double maxMagnitude = 1e100;

  /// Non-zero results smaller than this are reported as underflow.
  static const double minMagnitude = 1e-100;

  double? _accumulator;
  String _entry = '0';
  Operator? _pending;
  CalcPhase _phase = CalcPhase.ready;
  CalcError? _error;

  /// State from just before the step that failed, restored by ⌫.
  _Snapshot? _recovery;

  /// Why the last input was refused, set by [_reject] for one step.
  String? _notice;
  String _lastExpression = '';
  final List<Transition> _tape = [];

  /// Everything applied so far in this calculation, e.g. `2 + 3 × 4`.
  String _chain = '';

  /// True when [_entry] holds a recalled result rather than typed digits, so
  /// the next digit replaces it instead of appending (`20` + `1` ≠ `201`).
  bool _entryRecalled = false;

  /// Oldest first; the UI shows it reversed.
  final List<HistoryEntry> _history = [];

  // ---------------------------------------------------------------------------
  // Read-only view of the state
  // ---------------------------------------------------------------------------

  CalcPhase get phase => _phase;
  double? get accumulator => _accumulator;
  Operator? get pendingOperator => _pending;
  String get entry => _entry;
  CalcError? get error => _error;
  String? get errorMessage => _error?.title;

  /// One-line help under the display: how to recover from an error, or why
  /// the last key was refused. Null when there's nothing to say.
  String? get hint => _error?.hint ?? _notice;
  List<Transition> get tape => List.unmodifiable(_tape);
  Transition? get lastTransition => _tape.isEmpty ? null : _tape.last;
  List<HistoryEntry> get history => List.unmodifiable(_history);

  /// Main display, derived from the phase.
  String get display => switch (_phase) {
    CalcPhase.ready || CalcPhase.enteringOperand => _entry,
    CalcPhase.awaitingOperand || CalcPhase.result => format(_accumulator!),
    CalcPhase.error => _error!.title,
  };

  /// Secondary line above the display, e.g. `5 ×` or `5 × 4 =`.
  String get expression => switch (_phase) {
    CalcPhase.awaitingOperand || CalcPhase.enteringOperand
        when _pending != null =>
      '${format(_accumulator!)} ${_pending!.symbol}',
    CalcPhase.result => _lastExpression,
    _ => '',
  };

  // ---------------------------------------------------------------------------
  // Inputs
  // ---------------------------------------------------------------------------

  void inputDigit(int digit) {
    assert(digit >= 0 && digit <= 9);
    final d = '$digit';
    _step(d, () {
      switch (_phase) {
        case CalcPhase.result:
        case CalcPhase.error:
          _reset();
          _entry = d;
          _phase = CalcPhase.enteringOperand;
          return 'fresh calculation';
        case CalcPhase.ready:
        case CalcPhase.awaitingOperand:
          _entry = d;
          _phase = CalcPhase.enteringOperand;
          return 'start operand';
        case CalcPhase.enteringOperand:
          if (_entryRecalled) {
            _entry = d;
            _entryRecalled = false;
            return 'replace recalled value';
          }
          if (_entry == '0') {
            _entry = d;
            return 'replace leading 0';
          }
          if (_digitCount(_entry) >= maxDigits) {
            return _reject(
              'ignored: $maxDigits-digit limit',
              'Numbers can have up to $maxDigits digits',
            );
          }
          _entry += d;
          return 'append';
      }
    });
  }

  void inputDecimal() {
    _step('.', () {
      switch (_phase) {
        case CalcPhase.result:
        case CalcPhase.error:
          _reset();
          _entry = '0.';
          _phase = CalcPhase.enteringOperand;
          return 'fresh calculation';
        case CalcPhase.ready:
        case CalcPhase.awaitingOperand:
          _entry = '0.';
          _phase = CalcPhase.enteringOperand;
          return 'start operand at 0.';
        case CalcPhase.enteringOperand:
          if (_entryRecalled) {
            _entry = '0.';
            _entryRecalled = false;
            return 'replace recalled value';
          }
          if (_entry.contains('.')) {
            return _reject(
              'ignored: already has a point',
              'A number can only have one decimal point',
            );
          }
          _entry += '.';
          return 'append point';
      }
    });
  }

  void chooseOperator(Operator op) {
    _step(op.symbol, () {
      switch (_phase) {
        case CalcPhase.error:
          return _reject('ignored: clear the error first', _error!.hint);
        case CalcPhase.awaitingOperand:
          final old = _pending!;
          _pending = op;
          return 'replace ${old.symbol} with ${op.symbol}';
        case CalcPhase.result:
          _chain = format(_accumulator!);
          _pending = op;
          _phase = CalcPhase.awaitingOperand;
          return 'continue from result';
        case CalcPhase.ready:
        case CalcPhase.enteringOperand:
          final operand = _parse(_entry);
          final String note;
          if (_pending == null) {
            _accumulator = operand;
            _chain = format(operand);
            note = 'store ${format(operand)}';
          } else {
            final before = _accumulator!;
            final value = _apply(before, _pending!, operand);
            _accumulator = value;
            _chain += ' ${_pending!.symbol} ${format(operand)}';
            note =
                'apply ${format(before)} ${_pending!.symbol} '
                '${format(operand)} = ${format(value)}';
          }
          _entryRecalled = false;
          _pending = op;
          _phase = CalcPhase.awaitingOperand;
          return note;
      }
    });
  }

  void equals() {
    _step('=', () {
      switch (_phase) {
        case CalcPhase.awaitingOperand:
          return _reject(
            'ignored: awaiting operand',
            'Enter a number after ${_pending!.symbol}',
          );
        case CalcPhase.error:
          return _reject('ignored: clear the error first', _error!.hint);
        case CalcPhase.enteringOperand when _pending != null:
          break;
        case CalcPhase.ready || CalcPhase.enteringOperand:
          return _reject(
            'ignored: nothing pending',
            'Choose an operator first',
          );
        case CalcPhase.result:
          return 'ignored: already finished';
      }
      final before = _accumulator!;
      final op = _pending!;
      final operand = _parse(_entry);
      final value = _apply(before, op, operand);
      _lastExpression = '${format(before)} ${op.symbol} ${format(operand)} =';
      _chain += ' ${op.symbol} ${format(operand)}';
      _addHistory(HistoryEntry(chain: _chain, result: value));
      _accumulator = value;
      _pending = null;
      _entryRecalled = false;
      _phase = CalcPhase.result;
      return 'finish ${format(value)}';
    });
  }

  /// Reuses a history result as the current operand. With an operator
  /// pending it fills the next operand (`5 ×` + recall 4 → `5 × 4`);
  /// otherwise it starts a fresh calculation from that value.
  void recall(HistoryEntry item) {
    _step('↺', () {
      _checkRange(item.result, invalid: CalcError.invalidNumber);
      final text = format(item.result);
      final String note;
      if (_phase == CalcPhase.awaitingOperand ||
          (_phase == CalcPhase.enteringOperand && _pending != null)) {
        note = 'recall $text as operand';
      } else {
        _reset();
        note = 'recall $text, fresh calculation';
      }
      _entry = text;
      _entryRecalled = true;
      _phase = CalcPhase.enteringOperand;
      return note;
    });
  }

  /// Empties history and returns what was removed, so the UI can offer undo.
  /// Does not touch the current calculation.
  List<HistoryEntry> clearHistory() {
    final removed = List<HistoryEntry>.of(_history);
    _history.clear();
    return removed;
  }

  /// Puts back entries from [clearHistory], ahead of anything added since.
  void restoreHistory(List<HistoryEntry> entries) {
    _history.insertAll(0, entries);
    if (_history.length > historyLength) {
      _history.removeRange(0, _history.length - historyLength);
    }
  }

  void _addHistory(HistoryEntry item) {
    _history.add(item);
    if (_history.length > historyLength) _history.removeAt(0);
  }

  /// AC: wipes operand, accumulator, pending operator and result phase.
  /// Also reached by long-pressing ⌫, which is labelled as such on the tape.
  void allClear({bool fromLongPress = false}) {
    _step(fromLongPress ? '⌫' : 'AC', () {
      _reset();
      return fromLongPress
          ? 'long-press: reset everything'
          : 'reset everything';
    });
  }

  /// ⌫: steps back one input. Returns false when the press was refused, so
  /// the UI can give "can't do that" feedback.
  ///
  /// - typing: drop the last character (`1.5` → `1.` → `1`)
  /// - last character of an operand: back to the previous phase
  ///   (`2 + 3` → `2 +`, or `7` → ready)
  /// - recalled value: removed as a whole
  /// - just chose an operator: un-choose it, keeping the running total
  ///   (`2 + 3 ×` → `5`)
  /// - result: refused, a finished result is not edited digit by digit
  /// - error: back to just before the failing step (`8 ÷ 0 =` → `8 ÷ 0`)
  bool backspace() {
    _step('⌫', () {
      switch (_phase) {
        case CalcPhase.ready:
          return _reject('ignored: nothing to delete', 'Nothing to delete');
        case CalcPhase.result:
          return _reject(
            'ignored: result is final',
            'Results can\'t be edited. Hold ⌫ or press AC to clear',
          );
        case CalcPhase.error:
          final saved = _recovery;
          if (saved == null) {
            _reset();
            return 'dismiss error';
          }
          _restore(saved);
          return 'undo failed step';
        case CalcPhase.awaitingOperand:
          final op = _pending!;
          _entry = format(_accumulator!);
          _entryRecalled = true;
          _accumulator = null;
          _pending = null;
          _phase = CalcPhase.enteringOperand;
          return 'remove pending ${op.symbol}';
        case CalcPhase.enteringOperand:
          final String note;
          if (_entryRecalled) {
            _entry = '';
            note = 'remove recalled value';
          } else {
            final removed = _entry[_entry.length - 1];
            _entry = _entry.substring(0, _entry.length - 1);
            note = removed == '.' ? 'remove point' : 'remove $removed';
          }
          // "0" counts as empty here, otherwise ⌫ on a lone 0 would be a no-op.
          if (_entry.isEmpty ||
              _entry == '-' ||
              (_entry == '0' && note != 'remove point')) {
            _entry = '0';
            _entryRecalled = false;
            _phase = _pending == null
                ? CalcPhase.ready
                : CalcPhase.awaitingOperand;
            return '$note, operand empty';
          }
          return note;
      }
    });
    return !_tape.last.rejected;
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Runs [action], which mutates state and returns a short note, then
  /// records the transition on the tape.
  ///
  /// This is the single place errors are handled: a [CalculationException]
  /// (or anything unexpected) rolls state back to before the step, then
  /// enters the error phase with that snapshot kept for ⌫ to restore.
  void _step(String input, String Function() action) {
    final from = _phase;
    final before = _snapshot();
    _notice = null;
    var rejected = false;
    String note;
    try {
      note = action();
      rejected = _notice != null;
    } on CalculationException catch (e) {
      _enterError(e.error, recovery: before);
      note = 'error: ${e.error.title}';
    } on Exception catch (e) {
      _enterError(CalcError.unexpected, recovery: null);
      note = 'error: unexpected ($e)';
    }
    _tape.add(
      Transition(
        input: input,
        from: from,
        to: _phase,
        display: display,
        note: note,
        rejected: rejected,
      ),
    );
    if (_tape.length > tapeLength) _tape.removeAt(0);
  }

  /// Refuses an input: state is unchanged, [hint] tells the user why.
  String _reject(String note, String hint) {
    _notice = hint;
    return note;
  }

  void _reset() {
    _accumulator = null;
    _entry = '0';
    _pending = null;
    _phase = CalcPhase.ready;
    _error = null;
    _recovery = null;
    _lastExpression = '';
    _chain = '';
    _entryRecalled = false;
  }

  void _enterError(CalcError error, {required _Snapshot? recovery}) {
    _reset();
    _error = error;
    _recovery = recovery;
    _phase = CalcPhase.error;
  }

  _Snapshot _snapshot() => (
    accumulator: _accumulator,
    entry: _entry,
    pending: _pending,
    phase: _phase,
    lastExpression: _lastExpression,
    chain: _chain,
    entryRecalled: _entryRecalled,
  );

  void _restore(_Snapshot s) {
    _reset();
    _accumulator = s.accumulator;
    _entry = s.entry;
    _pending = s.pending;
    _phase = s.phase;
    _lastExpression = s.lastExpression;
    _chain = s.chain;
    _entryRecalled = s.entryRecalled;
  }

  /// Applies one operation. Throws [CalculationException] for ÷ 0 and for
  /// results outside the supported range.
  double _apply(double a, Operator op, double b) {
    if (op == Operator.divide && b == 0) {
      throw const CalculationException(CalcError.divideByZero);
    }
    final value = switch (op) {
      Operator.add => a + b,
      Operator.subtract => a - b,
      Operator.multiply => a * b,
      Operator.divide => a / b,
    };
    _checkRange(value);
    return value;
  }

  /// Overflow at ±[maxMagnitude] (or infinity), underflow for non-zero
  /// values below [minMagnitude]. NaN reports [invalid].
  static void _checkRange(
    double value, {
    CalcError invalid = CalcError.overflow,
  }) {
    if (value.isNaN) throw CalculationException(invalid);
    if (value.isInfinite) throw CalculationException(invalid);
    if (value.abs() >= maxMagnitude) {
      throw const CalculationException(CalcError.overflow);
    }
    if (value != 0 && value.abs() < minMagnitude) {
      throw const CalculationException(CalcError.underflow);
    }
  }

  /// Parses the operand text, rejecting anything that isn't a finite number.
  static double _parse(String text) {
    final trimmed = text.endsWith('.')
        ? text.substring(0, text.length - 1)
        : text;
    final value = double.tryParse(trimmed);
    if (value == null || !value.isFinite) {
      throw const CalculationException(CalcError.invalidNumber);
    }
    return value;
  }

  static int _digitCount(String text) =>
      text.replaceAll(RegExp(r'[^0-9]'), '').length;

  /// Formats a value for the display: whole numbers without `.0`, and
  /// floating-point noise trimmed (`0.1 + 0.2` shows `0.3`).
  static String format(double value) {
    if (value == value.truncateToDouble() && value.abs() < 1e15) {
      return value.toInt().toString();
    }
    final text = value.toStringAsPrecision(12);
    final e = text.indexOf('e');
    if (e == -1) return _trimZeros(text);
    return '${_trimZeros(text.substring(0, e))}${text.substring(e)}';
  }

  static String _trimZeros(String text) {
    if (!text.contains('.')) return text;
    return text
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }
}
