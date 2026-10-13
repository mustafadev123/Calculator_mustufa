import 'package:flutter/material.dart';

import '../logic/calculator_engine.dart';
import '../theme.dart';
import 'state_tape.dart';

/// Top half of the screen: phase chip, optional state tape, the expression
/// line (`5 ×`) and the running total.
class DisplayPanel extends StatelessWidget {
  const DisplayPanel({
    super.key,
    required this.engine,
    required this.showTape,
    required this.onToggleTape,
    required this.onOpenHistory,
  });

  final CalculatorEngine engine;
  final bool showTape;
  final VoidCallback onToggleTape;
  final VoidCallback onOpenHistory;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final phase = engine.phase;
    final isError = phase == CalcPhase.error;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: phase.color(scheme).withValues(alpha: 0.5),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Row(
            children: [
              _PhaseChip(phase: phase),
              const Spacer(),
              Badge.count(
                count: engine.history.length,
                isLabelVisible: engine.history.isNotEmpty,
                child: IconButton.filledTonal(
                  key: const Key('history_open'),
                  onPressed: onOpenHistory,
                  tooltip: 'History, ${engine.history.length} items',
                  icon: const Icon(Icons.history),
                ),
              ),
              const SizedBox(width: 4),
              IconButton.filledTonal(
                key: const Key('tape_toggle'),
                onPressed: onToggleTape,
                isSelected: showTape,
                tooltip: showTape ? 'Hide state tape' : 'Show state tape',
                icon: const Icon(Icons.receipt_long_outlined),
                selectedIcon: const Icon(Icons.receipt_long),
              ),
            ],
          ),
          if (showTape) Expanded(child: StateTape(transitions: engine.tape)),
          const SizedBox(height: 8),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: engine.hint == null
                ? const SizedBox(width: double.infinity)
                : _HintLine(
                    key: ValueKey(engine.hint),
                    text: engine.hint!,
                    isError: isError,
                  ),
          ),
          Text(
            engine.expression,
            key: const Key('display_expression'),
            textAlign: TextAlign.right,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleLarge?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          // Flexible: full 84px when there's room, shrinks (and the number
          // scales down) on short screens or when a hint or the tape is shown.
          Flexible(
            child: Semantics(
              liveRegion: true,
              label: isError
                  ? 'Error: ${engine.display}'
                  : 'Display ${engine.display}',
              excludeSemantics: true,
              child: SizedBox(
                height: 84,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 160),
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween(
                        begin: const Offset(0, 0.15),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  ),
                  layoutBuilder: (current, previous) => Stack(
                    alignment: Alignment.centerRight,
                    children: [...previous, ?current],
                  ),
                  child: FittedBox(
                    key: ValueKey(engine.display),
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      engine.display,
                      key: const Key('display_value'),
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: isError ? 40 : 68,
                        fontWeight: FontWeight.w300,
                        color: isError ? scheme.error : scheme.onSurface,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Recovery hint for an error, or why the last key was refused. A live
/// region, so TalkBack reads it out as soon as it appears.
class _HintLine extends StatelessWidget {
  const _HintLine({super.key, required this.text, required this.isError});

  final String text;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = isError ? scheme.error : scheme.onSurfaceVariant;
    return Semantics(
      liveRegion: true,
      container: true,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.info_outline,
              size: 16,
              color: color,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                text,
                key: const Key('display_hint'),
                textAlign: TextAlign.right,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhaseChip extends StatelessWidget {
  const _PhaseChip({required this.phase});

  final CalcPhase phase;

  @override
  Widget build(BuildContext context) {
    final color = phase.color(Theme.of(context).colorScheme);
    return Semantics(
      label: 'State: ${phase.spoken}',
      excludeSemantics: true,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.circle, size: 8, color: color),
            const SizedBox(width: 6),
            Text(
              phase.label,
              key: const Key('phase_chip'),
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
