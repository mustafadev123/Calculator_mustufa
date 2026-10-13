import 'package:flutter/material.dart';

import '../logic/calculator_engine.dart';
import '../theme.dart';

/// A scrolling receipt of recent transitions, newest on top:
/// `[×]  ENTER → AWAIT   apply 2 + 3 = 5`.
class StateTape extends StatelessWidget {
  const StateTape({super.key, required this.transitions});

  final List<Transition> transitions;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (transitions.isEmpty) {
      return Center(
        child: Text(
          'Press a key to record a transition',
          style: TextStyle(color: scheme.onSurfaceVariant),
        ),
      );
    }

    final recent = transitions.reversed.toList();
    return ListView.builder(
      key: const Key('state_tape'),
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: recent.length,
      itemBuilder: (context, i) {
        final t = recent[i];
        final mono = TextStyle(
          fontFamily: 'monospace',
          fontSize: 12,
          color: i == 0 ? scheme.onSurface : scheme.onSurfaceVariant,
        );
        return Semantics(
          label: '${t.input}: ${t.from.spoken} to ${t.to.spoken}, ${t.note}',
          excludeSemantics: true,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                Container(
                  width: 30,
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(vertical: 1),
                  decoration: BoxDecoration(
                    border: Border.all(color: scheme.outlineVariant),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(t.input, style: mono.copyWith(fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 8),
                Text(t.from.label, style: mono.copyWith(color: t.from.color(scheme))),
                Text(' → ', style: mono),
                Text(t.to.label, style: mono.copyWith(color: t.to.color(scheme))),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(t.note, style: mono, overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
