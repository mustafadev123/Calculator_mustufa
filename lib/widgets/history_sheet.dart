import 'package:flutter/material.dart';

import '../logic/calculator_engine.dart';

/// Draggable bottom sheet listing finished calculations, newest first.
/// Tapping an entry reuses its result; "Clear" empties the list (the screen
/// offers undo). The sheet closes itself before calling either callback.
class HistorySheet extends StatelessWidget {
  const HistorySheet({
    super.key,
    required this.entries,
    required this.onRecall,
    required this.onClear,
  });

  /// Newest first.
  final List<HistoryEntry> entries;
  final ValueChanged<HistoryEntry> onRecall;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.55,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      builder: (context, controller) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 12, 4),
            child: Row(
              children: [
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text('History', style: theme.textTheme.titleLarge),
                  ),
                ),
                TextButton.icon(
                  key: const Key('history_clear'),
                  onPressed: entries.isEmpty
                      ? null
                      : () {
                          Navigator.pop(context);
                          onClear();
                        },
                  icon: const Icon(Icons.delete_sweep_outlined),
                  label: const Text('Clear'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: entries.isEmpty
                ? ListView(
                    controller: controller,
                    children: [
                      const SizedBox(height: 48),
                      Icon(
                        Icons.history_toggle_off,
                        size: 48,
                        color: scheme.outline,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No calculations yet',
                        key: const Key('history_empty'),
                        textAlign: TextAlign.center,
                        style: TextStyle(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  )
                : ListView.separated(
                    key: const Key('history_list'),
                    controller: controller,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: entries.length,
                    separatorBuilder: (_, _) =>
                        const Divider(indent: 20, endIndent: 20, height: 1),
                    itemBuilder: (context, i) {
                      final item = entries[i];
                      final result = CalculatorEngine.format(item.result);
                      return Semantics(
                        label: '${item.chain} equals $result',
                        hint: 'Reuse result',
                        excludeSemantics: true,
                        button: true,
                        onTap: () => _recall(context, item),
                        child: InkWell(
                          key: Key('history_item_$i'),
                          onTap: () => _recall(context, item),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  item.chain,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.right,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '= $result',
                                  style: theme.textTheme.headlineSmall
                                      ?.copyWith(color: scheme.primary),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _recall(BuildContext context, HistoryEntry item) {
    Navigator.pop(context);
    onRecall(item);
  }
}
