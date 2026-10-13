/// Everything that can put the calculator into its error phase, with a
/// short title for the display and a hint that says how to recover.
enum CalcError {
  divideByZero(
    'Can\'t divide by zero',
    'Press ⌫ to change the divisor, or a digit to start over',
  ),
  overflow(
    'Result too large',
    'Results must stay within ±1e100. Press ⌫ to go back',
  ),
  underflow(
    'Result too small',
    'Non-zero results must be at least 1e-100. Press ⌫ to go back',
  ),
  invalidNumber('Invalid number', 'Press ⌫ to go back, or AC to reset'),
  unexpected('Something went wrong', 'Press AC to reset');

  const CalcError(this.title, this.hint);

  final String title;
  final String hint;
}

/// Thrown inside the engine when a step can't complete. The engine catches
/// it in one place and turns it into the error phase, so no half-finished
/// state leaks out.
class CalculationException implements Exception {
  const CalculationException(this.error);

  final CalcError error;

  @override
  String toString() => 'CalculationException(${error.name}: ${error.title})';
}
