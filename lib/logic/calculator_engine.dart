/// Core state machine for the left-to-right running-total calculator.
///
/// The engine is plain Dart (no Flutter imports) so every transition can be
/// unit-tested without pumping widgets. The UI owns one engine instance and
/// calls these methods inside `setState()`.
///
/// Evaluation rule: no operator precedence. Each operator applies the pending
/// operation first, so `2 + 3 × 4 =` is `(2 + 3) × 4 = 20`.
library;

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

  /// Something went wrong (e.g. ÷ 0); any digit or AC recovers.
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
  });

  final String input;
  final CalcPhase from;
  final CalcPhase to;
  final String display;
  final String note;

  @override
  String toString() => '$input: ${from.name} → ${to.name} [$display] $note';
}

class CalculatorEngine {
  /// Longest operand we accept, counting digits only.
  static const int maxDigits = 15;

  /// How many transitions the tape keeps before dropping the oldest.
  static const int tapeLength = 50;

  double? _accumulator;
  String _entry = '0';
  Operator? _pending;
  CalcPhase _phase = CalcPhase.ready;
  String? _errorMessage;
  String _lastExpression = '';
  final List<Transition> _tape = [];

  // ---------------------------------------------------------------------------
  // Read-only view of the state
  // ---------------------------------------------------------------------------

  CalcPhase get phase => _phase;
  double? get accumulator => _accumulator;
  Operator? get pendingOperator => _pending;
  String get entry => _entry;
  String? get errorMessage => _errorMessage;
  List<Transition> get tape => List.unmodifiable(_tape);
  Transition? get lastTransition => _tape.isEmpty ? null : _tape.last;

  /// Main display, derived from the phase.
  String get display => switch (_phase) {
        CalcPhase.ready || CalcPhase.enteringOperand => _entry,
        CalcPhase.awaitingOperand || CalcPhase.result => format(_accumulator!),
        CalcPhase.error => _errorMessage!,
      };

  /// Secondary line above the display, e.g. `5 ×` or `5 × 4 =`.
  String get expression => switch (_phase) {
        CalcPhase.awaitingOperand ||
        CalcPhase.enteringOperand when _pending != null =>
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
          if (_entry == '0') {
            _entry = d;
            return 'replace leading 0';
          }
          if (_digitCount(_entry) >= maxDigits) {
            return 'ignored: $maxDigits-digit limit';
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
          if (_entry.contains('.')) return 'ignored: already has a point';
          _entry += '.';
          return 'append point';
      }
    });
  }

  void chooseOperator(Operator op) {
    _step(op.symbol, () {
      switch (_phase) {
        case CalcPhase.error:
          return 'ignored: clear the error first';
        case CalcPhase.awaitingOperand:
          final old = _pending!;
          _pending = op;
          return 'replace ${old.symbol} with ${op.symbol}';
        case CalcPhase.result:
          _pending = op;
          _phase = CalcPhase.awaitingOperand;
          return 'continue from result';
        case CalcPhase.ready:
        case CalcPhase.enteringOperand:
          final operand = _parse(_entry);
          final String note;
          if (_pending == null) {
            _accumulator = operand;
            note = 'store ${format(operand)}';
          } else {
            final before = _accumulator!;
            final value = _apply(before, _pending!, operand);
            if (value == null) return 'error: $_errorMessage';
            _accumulator = value;
            note = 'apply ${format(before)} ${_pending!.symbol} '
                '${format(operand)} = ${format(value)}';
          }
          _pending = op;
          _phase = CalcPhase.awaitingOperand;
          return note;
      }
    });
  }

  void equals() {
    _step('=', () {
      if (_phase == CalcPhase.awaitingOperand) {
        return 'ignored: awaiting operand';
      }
      if (_phase != CalcPhase.enteringOperand || _pending == null) {
        return 'ignored: nothing pending';
      }
      final before = _accumulator!;
      final op = _pending!;
      final operand = _parse(_entry);
      final value = _apply(before, op, operand);
      if (value == null) return 'error: $_errorMessage';
      _lastExpression =
          '${format(before)} ${op.symbol} ${format(operand)} =';
      _accumulator = value;
      _pending = null;
      _phase = CalcPhase.result;
      return 'finish ${format(value)}';
    });
  }

  /// AC: wipes operand, accumulator, pending operator and result phase.
  void allClear() {
    _step('AC', () {
      _reset();
      return 'reset everything';
    });
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Runs [action], which mutates state and returns a short note, then
  /// records the transition on the tape.
  void _step(String input, String Function() action) {
    final from = _phase;
    final note = action();
    _tape.add(Transition(
      input: input,
      from: from,
      to: _phase,
      display: display,
      note: note,
    ));
    if (_tape.length > tapeLength) _tape.removeAt(0);
  }

  void _reset() {
    _accumulator = null;
    _entry = '0';
    _pending = null;
    _phase = CalcPhase.ready;
    _errorMessage = null;
    _lastExpression = '';
  }

  /// Applies one operation, or moves to [CalcPhase.error] and returns null.
  double? _apply(double a, Operator op, double b) {
    if (op == Operator.divide && b == 0) {
      return _fail('Can\'t divide by zero');
    }
    final value = switch (op) {
      Operator.add => a + b,
      Operator.subtract => a - b,
      Operator.multiply => a * b,
      Operator.divide => a / b,
    };
    if (!value.isFinite) return _fail('Overflow');
    return value;
  }

  double? _fail(String message) {
    _errorMessage = message;
    _accumulator = null;
    _pending = null;
    _phase = CalcPhase.error;
    return null;
  }

  static double _parse(String text) =>
      double.parse(text.endsWith('.') ? text.substring(0, text.length - 1) : text);

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
    return text.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  }
}
