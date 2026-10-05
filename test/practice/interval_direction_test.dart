import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solfege_app/features/practice/screens/interval_direction_screen.dart';
import 'package:solfege_app/features/practice/trainers/interval_direction.dart';

void main() {
  test('a major sixth is one semitone wider than a minor sixth', () {
    expect(noteAbove(60, 'б6'), 69);
    expect(noteAbove(60, 'м6'), 68);
    expect(noteAbove(60, 'б6') - noteAbove(60, 'м6'), 1);
  });

  test('a fifth down from C5 is F4, not the fifth above', () {
    expect(noteBelow(72, 'ч5'), 65);
    expect(noteAbove(72, 'ч5'), 79);
    expect(placedUpward(72, 79), isTrue);
    expect(placedUpward(72, 65), isFalse);
  });

  test('inverting a major third yields a minor sixth and the numbers sum to 9', () {
    expect(invertedLabel('б3'), 'м6');
    expect(invertedLabel('б3'), isNot('б6'));
    expect(intervalNumber('б3') + intervalNumber('м6'), 9);
    expect(inversionRule('б3'), isTrue);
    expect(inversionRule('ч4'), isTrue);
    expect(pr04BuildStageOpen(3, countMastered: false), isFalse);
    expect(pr04BuildStageOpen(5, countMastered: true), isTrue);
  });

  testWidgets('building a major sixth a semitone too low is rejected', (tester) async {
    bool? answer;
    await tester.pumpWidget(
      MaterialApp(
        home: IntervalDirectionScreen(
          startMidi: 60,
          label: 'б6',
          upward: true,
          choices: const [68, 69],
          onAnswered: (value) => answer = value,
        ),
      ),
    );
    await tester.tap(find.text('соль-диез'));
    await tester.pump();
    expect(answer, isFalse);
  });

  testWidgets('placing a descending fifth upward is rejected', (tester) async {
    bool? answer;
    await tester.pumpWidget(
      MaterialApp(
        home: IntervalDirectionScreen(
          startMidi: 72,
          label: 'ч5',
          upward: false,
          choices: const [65, 79],
          onAnswered: (value) => answer = value,
        ),
      ),
    );
    await tester.tap(find.text('соль'));
    await tester.pump();
    expect(answer, isFalse);
    expect(noteBelow(72, 'ч5'), 65);
  });
}
