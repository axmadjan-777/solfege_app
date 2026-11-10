import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solfege_app/features/practice/screens/interval_build_screen.dart';

void main() {
  testWidgets('mi then sol completes the third and fifth from do correctly',
      (tester) async {
    final results = <bool>[];
    await tester.pumpWidget(MaterialApp(
      home: IntervalBuildScreen(onFinished: results.add),
    ));

    await tester.tap(find.widgetWithText(FilledButton, 'ми'));
    await tester.pump();
    expect(results, isEmpty);

    await tester.tap(find.widgetWithText(FilledButton, 'соль'));
    await tester.pump();
    expect(results, [true]);
  });

  testWidgets('re then sol is rejected as an incorrect third and fifth',
      (tester) async {
    final results = <bool>[];
    await tester.pumpWidget(MaterialApp(
      home: IntervalBuildScreen(onFinished: results.add),
    ));

    await tester.tap(find.widgetWithText(FilledButton, 'ре'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'соль'));
    await tester.pump();

    expect(results, [false]);
  });
}
