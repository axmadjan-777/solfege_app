import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solfege_app/features/interaction/templates/level01_templates.dart';

void main() {
  testWidgets('T03 gives partial credit and then a full answer', (tester) async {
    final results = <TemplateResult>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MultiChoiceTemplate(
            prompt: 'Найди все До',
            options: const ['до', 'ре', 'до'],
            correctIndexes: const {0, 2},
            onResult: results.add,
          ),
        ),
      ),
    );

    await tester.tap(find.widgetWithText(CheckboxListTile, 'до').first);
    await tester.pump();
    await tester.tap(find.text('Проверить'));
    await tester.pump();

    expect(results.single.feedback, 'Частично');
    expect(results.single.correct, isFalse);
    expect(results.single.credit, greaterThan(0));
    expect(results.single.credit, lessThan(1));
  });

  testWidgets('T04 records a completed order', (tester) async {
    TemplateResult? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OrderTemplate(
            prompt: 'По порядку',
            items: const ['ми', 'до', 'ре'],
            correctOrder: const ['до', 'ре', 'ми'],
            onResult: (value) => result = value,
          ),
        ),
      ),
    );

    await tester.tap(find.text('до'));
    await tester.tap(find.text('ре'));
    await tester.tap(find.text('ми'));
    await tester.pump();

    expect(result, isNotNull);
    expect(result!.feedback, 'Верно');
    expect(result!.correct, isTrue);
  });

  testWidgets('T06 accepts the right key', (tester) async {
    TemplateResult? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: KeyboardTemplate(
            prompt: 'Нажми до',
            whiteNotes: const [(label: 'до', midi: 60), (label: 'ре', midi: 62)],
            blackNotes: const [(label: 'до-диез', midi: 61)],
            correctMidi: 60,
            onResult: (value) => result = value,
          ),
        ),
      ),
    );

    await tester.tap(find.text('до'));
    await tester.pump();

    expect(result!.feedback, 'Верно');
    expect(find.text('до-диез'), findsOneWidget);
  });

  testWidgets('T11 records a matched pair', (tester) async {
    TemplateResult? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MatchPairsTemplate(
            prompt: 'Соедини',
            left: const ['до'],
            right: const ['C'],
            pairs: const {'до': 'C'},
            onResult: (value) => result = value,
          ),
        ),
      ),
    );

    await tester.tap(find.text('до'));
    await tester.pump();
    await tester.tap(find.text('C'));
    await tester.pump();

    expect(result!.feedback, 'Верно');
    expect(result!.correct, isTrue);
  });
}
