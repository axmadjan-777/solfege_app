import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:solfege_app/features/curriculum/data/curriculum_catalog.dart';
import 'package:solfege_app/features/practice/audio/practice_audio_player.dart';
import 'package:solfege_app/features/practice/progress/attempt.dart';
import 'package:solfege_app/features/practice/progress/clock.dart';
import 'package:solfege_app/features/practice/progress/error_return.dart';
import 'package:solfege_app/features/practice/progress/practice_attempt.dart';
import 'package:solfege_app/features/practice/progress/progress_store.dart';
import 'package:solfege_app/features/practice/screens/practice_round_screen.dart';

late CurriculumCatalog catalog;

void main() {
  setUpAll(() {
    catalog = CurriculumCatalog.fromDecoded(
      levels: _read('levels.json'),
      sourceMap: _read('source-map.json'),
      audioManifest: _read('audio-manifest.json'),
      exercises: _read('exercises.json'),
      competencies: _read('competencies.json'),
      lessons: _read('lessons.json'),
    );
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('stability and status survive a new launch', (tester) async {
    final preferences = await SharedPreferences.getInstance();
    final clock = FixedClock(DateTime.utc(2026, 10, 5));
    final store = _store(preferences, clock);
    final competency = competencyOf(
        catalog.practiceSets.firstWhere((set) => set.id == 'PR-03'));

    await tester.pumpWidget(_round(store, clock));
    await tester.pump();
    await tester.tap(find.text('м3'));
    await tester.pump();
    expect(find.text('Устойчивость 1/3'), findsOneWidget);
    expect(store.snapshot(competency).status, CompetencyStatus.practicing);

    final reloaded = _store(preferences, clock);
    expect(reloaded.snapshot(competency).stability.sessions, hasLength(1));
    expect(
        reloaded.snapshot(competency).stability.sessions.single.tonality, 'C');
    expect(reloaded.snapshot(competency).status, CompetencyStatus.practicing);

    await tester.pumpWidget(_round(reloaded, clock));
    await tester.pump();
    expect(find.text('Устойчивость 1/3'), findsOneWidget);
    expect(find.text('В практике'), findsOneWidget);
    expect(find.text('Освоено'), findsNothing);
  });

  test('a next-day return survives a new launch', () async {
    final preferences = await SharedPreferences.getInstance();
    final clock = FixedClock(DateTime.utc(2026, 10, 5, 8));
    _store(preferences, clock).scheduleNextDayReturn('PR-08');

    final reloaded = _store(preferences, clock);
    expect(reloaded.book.returns.single.tag, 'PR-08');
    expect(
      dueReturnTags(
        scheduled: reloaded.book.returns,
        now: clock.now().add(const Duration(hours: 23)),
      ),
      isEmpty,
    );
    expect(
      dueReturnTags(
        scheduled: reloaded.book.returns,
        now: clock.now().add(const Duration(days: 1)),
      ),
      ['PR-08'],
    );
  });
}

Widget _round(ProgressStore store, Clock clock) {
  return MaterialApp(
    home: PracticeRoundScreen(
      setId: 'PR-03',
      player: FakePracticeAudioPlayer(),
      catalog: catalog,
      progress: store,
      clock: clock,
    ),
  );
}

SharedPreferencesProgressStore _store(
    SharedPreferences preferences, Clock clock) {
  return SharedPreferencesProgressStore(
    preferences: preferences,
    clock: clock,
    rules: catalog.config.masteryRules,
  );
}

Map<String, dynamic> _read(String name) {
  return Map<String, dynamic>.from(
      jsonDecode(File('assets/curriculum/$name').readAsStringSync()) as Map);
}
