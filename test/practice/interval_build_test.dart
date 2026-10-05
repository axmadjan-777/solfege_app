import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solfege_app/features/practice/screens/interval_build_screen.dart';
import 'package:solfege_app/features/practice/trainers/interval_count.dart';

void main() {
  test('counting only the steps between the notes is not a fourth', () {
    expect(degreeSpan(1, 4), 4);
    expect(degreeSpan(1, 4) - 1, 3);
  });

  testWidgets('stage 2 accepts a third and then a fifth above do', (tester) async {
    bool? ok;
    await tester.pumpWidget(
      MaterialApp(home: IntervalBuildScreen(onFinished: (value) => ok = value)),
    );
    await tester.tap(find.widgetWithText(FilledButton, 'ми'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'соль'));
    await tester.pump();
    expect(ok, isTrue);
  });
}
