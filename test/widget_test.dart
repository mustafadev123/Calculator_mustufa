import 'package:calculator_app/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Taps keys by their widget keys, e.g. `tapKeys(tester, ['2', 'add', '3'])`.
Future<void> tapKeys(WidgetTester tester, List<String> keys) async {
  for (final k in keys) {
    await tester.tap(find.byKey(Key('key_$k')));
    await tester.pumpAndSettle();
  }
}

String displayText(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const Key('display_value'))).data!;

String expressionText(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const Key('display_expression'))).data!;

String phaseText(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const Key('phase_chip'))).data!;

void main() {
  testWidgets('starts at 0 in READY', (tester) async {
    await tester.pumpWidget(const CalculatorApp());
    expect(displayText(tester), '0');
    expect(phaseText(tester), 'READY');
  });

  testWidgets('2 + 3 × 4 = shows running total 5, then 20', (tester) async {
    await tester.pumpWidget(const CalculatorApp());

    await tapKeys(tester, ['2', 'add', '3']);
    expect(displayText(tester), '3');
    expect(expressionText(tester), '2 +');

    await tapKeys(tester, ['multiply']);
    expect(displayText(tester), '5');
    expect(expressionText(tester), '5 ×');
    expect(phaseText(tester), 'AWAIT');

    await tapKeys(tester, ['4', 'equals']);
    expect(displayText(tester), '20');
    expect(expressionText(tester), '5 × 4 =');
    expect(phaseText(tester), 'RESULT');
  });

  testWidgets('decimal keys: 1.5 × 1.5 = 2.25', (tester) async {
    await tester.pumpWidget(const CalculatorApp());
    await tapKeys(tester, ['1', 'decimal', '5', 'multiply', '1', 'decimal', '5', 'equals']);
    expect(displayText(tester), '2.25');
  });

  testWidgets('AC resets display and phase', (tester) async {
    await tester.pumpWidget(const CalculatorApp());
    await tapKeys(tester, ['9', 'add', '1', 'ac']);
    expect(displayText(tester), '0');
    expect(expressionText(tester), '');
    expect(phaseText(tester), 'READY');
  });

  testWidgets('pending operator is marked selected for accessibility', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(const CalculatorApp());
    await tapKeys(tester, ['7', 'add']);
    expect(
      tester.getSemantics(find.bySemanticsLabel('plus')),
      matchesSemantics(label: 'plus', isButton: true, isSelected: true, hasSelectedState: true, hasTapAction: true),
    );
    expect(
      tester.getSemantics(find.bySemanticsLabel('minus')),
      matchesSemantics(label: 'minus', isButton: true, hasSelectedState: true, hasTapAction: true),
    );
    handle.dispose();
  });

  testWidgets('state tape shows the latest transition note', (tester) async {
    await tester.pumpWidget(const CalculatorApp());
    await tapKeys(tester, ['2', 'add', '3', 'multiply']);
    await tester.tap(find.byKey(const Key('tape_toggle')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('state_tape')), findsOneWidget);
    expect(find.text('apply 2 + 3 = 5'), findsOneWidget);
  });

  group('History sheet', () {
    testWidgets('shows an empty state before any calculation', (tester) async {
      await tester.pumpWidget(const CalculatorApp());
      await tester.tap(find.byKey(const Key('history_open')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('history_empty')), findsOneWidget);
    });

    testWidgets('lists calculations newest first with a count badge', (tester) async {
      await tester.pumpWidget(const CalculatorApp());
      await tapKeys(tester, ['2', 'add', '3', 'multiply', '4', 'equals']);
      await tapKeys(tester, ['9', 'subtract', '1', 'equals']);
      expect(
        find.descendant(of: find.byType(Badge), matching: find.text('2')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('history_open')));
      await tester.pumpAndSettle();
      expect(find.text('2 + 3 × 4'), findsOneWidget);
      expect(find.text('= 20'), findsOneWidget);
      expect(find.text('9 − 1'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('9 − 1')).dy,
        lessThan(tester.getTopLeft(find.text('2 + 3 × 4')).dy),
      );
    });

    testWidgets('tapping an entry reuses its result in the pending operation', (tester) async {
      await tester.pumpWidget(const CalculatorApp());
      await tapKeys(tester, ['2', 'add', '3', 'multiply', '4', 'equals']);
      await tapKeys(tester, ['ac', '5', 'add']);

      await tester.tap(find.byKey(const Key('history_open')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('history_item_0')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('history_list')), findsNothing); // sheet closed
      expect(displayText(tester), '20');
      expect(expressionText(tester), '5 +');
      await tapKeys(tester, ['equals']);
      expect(displayText(tester), '25');
    });

    testWidgets('clear empties history and Undo restores it', (tester) async {
      await tester.pumpWidget(const CalculatorApp());
      await tapKeys(tester, ['6', 'multiply', '7', 'equals']);

      await tester.tap(find.byKey(const Key('history_open')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('history_clear')));
      await tester.pumpAndSettle();
      expect(find.text('Cleared 1 calculation'), findsOneWidget);
      expect(displayText(tester), '42'); // calculation untouched

      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('history_open')));
      await tester.pumpAndSettle();
      expect(find.text('6 × 7'), findsOneWidget);
    });
  });

  group('Backspace key', () {
    testWidgets('tap deletes the last digit', (tester) async {
      await tester.pumpWidget(const CalculatorApp());
      await tapKeys(tester, ['4', '5', '6', 'backspace']);
      expect(displayText(tester), '45');
    });

    testWidgets('long-press clears everything with a confirmation', (tester) async {
      await tester.pumpWidget(const CalculatorApp());
      await tapKeys(tester, ['9', 'multiply', '9']);
      await tester.longPress(find.byKey(const Key('key_backspace')));
      await tester.pumpAndSettle();
      expect(displayText(tester), '0');
      expect(expressionText(tester), '');
      expect(phaseText(tester), 'READY');
      expect(find.text('All cleared'), findsOneWidget);
    });

    testWidgets('refused delete on a result shakes the display', (tester) async {
      await tester.pumpWidget(const CalculatorApp());
      await tapKeys(tester, ['2', 'add', '2', 'equals']);
      final panel = find.byKey(const Key('display_value'));
      final restX = tester.getTopLeft(panel).dx;

      await tester.tap(find.byKey(const Key('key_backspace')));
      await tester.pump(); // rebuild starts the shake at t = 0
      await tester.pump(const Duration(milliseconds: 40));
      expect(tester.getTopLeft(panel).dx, isNot(restX)); // mid-shake

      await tester.pumpAndSettle();
      expect(tester.getTopLeft(panel).dx, restX); // settles back
      expect(displayText(tester), '4');
    });

    testWidgets('announces delete with a hold hint', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(const CalculatorApp());
      expect(
        tester.getSemantics(find.bySemanticsLabel('delete')),
        matchesSemantics(
          label: 'delete',
          hint: 'hold to clear all',
          isButton: true,
          hasSelectedState: true,
          hasTapAction: true,
          hasLongPressAction: true,
        ),
      );
      handle.dispose();
    });
  });

  testWidgets('fits a small 320×568 screen with the tape open', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const CalculatorApp());
    await tester.tap(find.byKey(const Key('tape_toggle')));
    await tester.pumpAndSettle();
    await tapKeys(tester, ['9', '9', '9', '9', '9', '9', '9', '9', '9', 'multiply', '9', 'equals']);

    expect(tester.takeException(), isNull);
    expect(displayText(tester), '8999999991');
  });
}
