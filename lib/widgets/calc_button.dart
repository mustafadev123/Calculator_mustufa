import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum CalcButtonKind { digit, operator, action, equals }

/// A single keypad key with an ink ripple, haptic tick, and a screen-reader
/// label (so `×` is read as "multiply", not "times sign").
class CalcButton extends StatelessWidget {
  const CalcButton({
    super.key,
    required this.label,
    required this.semanticLabel,
    required this.onPressed,
    this.onLongPress,
    this.semanticHint,
    this.icon,
    this.kind = CalcButtonKind.digit,
    this.flex = 1,
    this.selected = false,
  });

  final String label;
  final String semanticLabel;
  final VoidCallback onPressed;

  /// Optional hold action, e.g. ⌫ held clears everything.
  final VoidCallback? onLongPress;

  /// Read after the label, e.g. "hold to clear all".
  final String? semanticHint;

  /// Shown instead of [label] when set.
  final IconData? icon;
  final CalcButtonKind kind;
  final int flex;

  /// Highlights the pending operator so the current state is visible.
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (background, foreground) = switch (kind) {
      CalcButtonKind.digit => (scheme.surfaceContainerHigh, scheme.onSurface),
      CalcButtonKind.operator when selected => (
        scheme.tertiary,
        scheme.onTertiary,
      ),
      CalcButtonKind.operator => (
        scheme.secondaryContainer,
        scheme.onSecondaryContainer,
      ),
      CalcButtonKind.action => (scheme.errorContainer, scheme.onErrorContainer),
      CalcButtonKind.equals => (scheme.primary, scheme.onPrimary),
    };

    void tap() {
      HapticFeedback.selectionClick();
      onPressed();
    }

    final VoidCallback? hold = onLongPress == null
        ? null
        : () {
            HapticFeedback.heavyImpact();
            onLongPress!();
          };

    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.all(5),
        child: Semantics(
          button: true,
          selected: selected,
          label: semanticLabel,
          hint: semanticHint,
          excludeSemantics: true,
          onTap: tap,
          onLongPress: hold,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(selected ? 14 : 24),
            ),
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                borderRadius: BorderRadius.circular(selected ? 14 : 24),
                onTap: tap,
                onLongPress: hold,
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: icon != null
                          ? Icon(icon, size: 28, color: foreground)
                          : Text(
                              label,
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: kind == CalcButtonKind.digit
                                    ? FontWeight.w400
                                    : FontWeight.w600,
                                color: foreground,
                              ),
                            ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
