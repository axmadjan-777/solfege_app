import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solfege_app/features/coach/coach_catalog.dart';
import 'package:solfege_app/features/coach/coach_controller.dart';
import 'package:solfege_app/features/coach/coach_layer.dart';
import 'package:solfege_app/features/curriculum/data/curriculum_catalog.dart';
import 'package:solfege_app/features/theory/level0/level0_plan.dart';
import 'package:solfege_app/features/theory/level0/level0_player.dart';
import 'package:solfege_app/features/theory/screens/theory_level_screen.dart';

void main() {
  test('eight steps ignore the wrong tap and a skip is remembered', () {
    final store = MemoryCoachPersistence();
    final coach = CoachController(persistence: store)..arm();
    expect(coachSteps, hasLength(8));
    expect(coach.step?.title, 'Короткий маршрут');
    coach.note('open-theory');
    expect(coach.index, 0);

    coach.advance();
    coach.note('open-theory');
    expect(coach.step?.title, 'Первый урок');
    coach.skip();
    expect(coach.done, isTrue);
    expect(coach.visible, isFalse);
    expect(store.done, isTrue);
  });

  testWidgets('the tour highlights eight actions and leaves the lesson for practice', (tester) async {
    tester.view.physicalSize = const Size(800, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final catalog = _catalog();
    final coach = CoachController(persistence: MemoryCoachPersistence())..arm();
    final navigatorKey = GlobalKey<NavigatorState>();
    var tab = 0;
    coach.onShowTab = (value) => tab = value;
    var decoy = 0;

    await tester.pumpWidget(
      CoachScope(
        controller: coach,
        child: MaterialApp(
          navigatorKey: navigatorKey,
          builder: (context, child) => CoachOverlay(
            navigatorKey: navigatorKey,
            child: child ?? const SizedBox.shrink(),
          ),
          home: Scaffold(
            body: Column(
              children: [
                const CoachTarget(
                  id: 'practice-heading',
                  child: Text('Практика'),
                ),
                Expanded(
                  child: TheoryLevelScreen(
                    catalog: catalog,
                    isMastered: (_) => false,
                    onOpen: (lesson) {
                      Navigator.of(navigatorKey.currentContext!).push(
                        MaterialPageRoute<void>(
                          builder: (_) => Level0Player(
                            plan: Level0Plan.fromLesson(lesson),
                            onFinished: (_) {},
                          ),
                        ),
                      );
                    },
                  ),
                ),
                TextButton(onPressed: () => decoy += 1, child: const Text('Не трогать')),
                CoachTarget(
                  id: 'nav-theory',
                  child: TextButton(
                    onPressed: () => coach.note('open-theory'),
                    child: const Text('Теория'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.text('Шаг 1 из 8'), findsOneWidget);
    await _tap(tester, find.text('Поехали'));
    expect(find.text('Открой теорию'), findsOneWidget);

    await _tap(tester, find.text('Не трогать'), warn: false);
    expect(decoy, 0);
    expect(find.text('Открой теорию'), findsOneWidget);

    await _tap(tester, find.widgetWithText(TextButton, 'Теория'));
    expect(find.text('Первый урок'), findsOneWidget);
    await _tap(tester, find.text('Музыкальный тон и шум'));
    expect(find.text('Прочитай и иди дальше'), findsOneWidget);
    await _tap(tester, find.widgetWithText(FilledButton, 'Дальше'));
    expect(find.text('Выбери ответ'), findsOneWidget);
    await _tap(tester, find.widgetWithText(FilledButton, 'можно спеть'));
    expect(find.text('Закрепи шаг'), findsOneWidget);
    await _tap(tester, find.widgetWithText(FilledButton, 'Дальше'));
    expect(find.text('Теперь практика'), findsOneWidget);

    await _tap(tester, find.text('К практике'));
    expect(find.text('Карта практики'), findsOneWidget);
    expect(tab, 2);
    expect(navigatorKey.currentState!.canPop(), isFalse);
    await _tap(tester, find.text('Понятно'));
    expect(find.byKey(const Key('coach-card')), findsNothing);
    expect(coach.done, isTrue);
  });
}

Future<void> _tap(WidgetTester tester, Finder finder, {bool warn = true}) async {
  await tester.pump();
  await tester.tap(finder, warnIfMissed: warn);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump();
}

CurriculumCatalog _catalog() {
  Map<String, dynamic> read(String name) {
    return Map<String, dynamic>.from(
      jsonDecode(File('assets/curriculum/$name').readAsStringSync()) as Map,
    );
  }

  return CurriculumCatalog.fromDecoded(
    levels: read('levels.json'),
    sourceMap: read('source-map.json'),
    audioManifest: read('audio-manifest.json'),
    exercises: read('exercises.json'),
    competencies: read('competencies.json'),
    lessons: read('lessons.json'),
  );
}
