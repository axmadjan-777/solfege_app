import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:solfege_app/features/curriculum/data/curriculum_catalog.dart';
import 'package:solfege_app/features/practice/progress/clock.dart';
import 'package:solfege_app/features/practice/progress/practice_progress_binding.dart';
import 'package:solfege_app/features/practice/progress/progress_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late CurriculumCatalog catalog;
  late FixedClock clock;

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
    clock = FixedClock(DateTime.utc(2026, 11, 4));
    SharedPreferences.setMockInitialValues({});
  });

  SessionDraft answer(String competency) => SessionDraft(
        competencyId: competency,
        sessionId: 'session-$competency',
        correct: const [true],
        policy: catalog.config.policy('RP-aural'),
        tonality: 'C',
      );

  String fixture(String owner, String competency) {
    final store = MemoryProgressStore(
      clock: clock,
      rules: catalog.config.masteryRules,
      userId: owner,
    );
    store.recordSession(answer(competency));
    final encoded = jsonEncode(store.book.toJson());
    store.dispose();
    return encoded;
  }

  SharedPreferencesProgressStore open(SharedPreferences prefs, String owner) =>
      SharedPreferencesProgressStore(
        preferences: prefs,
        clock: clock,
        rules: catalog.config.masteryRules,
        userId: owner,
      );

  test('A and B retain separate books after reopening both stores', () async {
    final prefs = await SharedPreferences.getInstance();
    final a = open(prefs, 'account-a');
    final b = open(prefs, 'account-b');
    a.recordSession(answer('sca.tonic'));
    b.recordSession(answer('not.anchors_treble'));
    a.dispose();
    b.dispose();

    final reloadedA = open(prefs, 'account-a');
    final reloadedB = open(prefs, 'account-b');
    addTearDown(reloadedA.dispose);
    addTearDown(reloadedB.dispose);
    expect(reloadedA.book.userId, 'account-a');
    expect(reloadedB.book.userId, 'account-b');
    expect(reloadedA.book.competencies.keys, ['sca.tonic']);
    expect(reloadedB.book.competencies.keys, ['not.anchors_treble']);
  });

  test('owned legacy book is copied without deleting its source', () async {
    final raw = fixture('account-a', 'sca.tonic');
    SharedPreferences.setMockInitialValues({'practice_progress_v1': raw});
    final prefs = await SharedPreferences.getInstance();
    final a = open(prefs, 'account-a');
    addTearDown(a.dispose);
    expect(a.book.attempts, hasLength(1));
    expect(prefs.getString('practice_progress_v1:account-a'), raw);
    expect(prefs.getString('practice_progress_v1'), raw);
    final b = open(prefs, 'account-b');
    addTearDown(b.dispose);
    expect(b.book.attempts, isEmpty);
  });

  for (final owner in ['local', 'another-account']) {
    test('legacy owner $owner is not assigned to the current account',
        () async {
      final raw = fixture(owner, 'sca.tonic');
      SharedPreferences.setMockInitialValues({'practice_progress_v1': raw});
      final prefs = await SharedPreferences.getInstance();
      final a = open(prefs, 'account-a');
      addTearDown(a.dispose);
      expect(a.book.userId, 'account-a');
      expect(a.book.attempts, isEmpty);
      expect(prefs.getString('practice_progress_v1'), raw);
      expect(prefs.containsKey('practice_progress_v1:account-a'), isFalse);
    });
  }

  test('existing scoped book takes precedence over owned legacy data',
      () async {
    SharedPreferences.setMockInitialValues({
      'practice_progress_v1': fixture('account-a', 'sca.tonic'),
      'practice_progress_v1:account-a':
          fixture('account-a', 'not.anchors_treble'),
    });
    final a = open(await SharedPreferences.getInstance(), 'account-a');
    addTearDown(a.dispose);
    expect(a.book.competencies.keys, ['not.anchors_treble']);
  });

  test('a foreign owner inside a scoped value is never exposed', () async {
    SharedPreferences.setMockInitialValues({
      'practice_progress_v1:account-a': fixture('account-b', 'sca.tonic'),
    });
    final a = open(await SharedPreferences.getInstance(), 'account-a');
    addTearDown(a.dispose);
    expect(a.book.userId, 'account-a');
    expect(a.book.attempts, isEmpty);
  });

  test('malformed scoped data fails without leaking into another account',
      () async {
    SharedPreferences.setMockInitialValues({
      'practice_progress_v1:account-a': 'not-json',
      'practice_progress_v1:account-b': fixture('account-b', 'sca.tonic'),
    });
    final prefs = await SharedPreferences.getInstance();
    expect(() => open(prefs, 'account-a'), throwsFormatException);
    expect(prefs.getString('practice_progress_v1:account-a'), 'not-json');
    final b = open(prefs, 'account-b');
    addTearDown(b.dispose);
    expect(b.book.userId, 'account-b');
    expect(b.book.attempts, hasLength(1));
  });

  test('progress changes notify the owning UI only', () async {
    final prefs = await SharedPreferences.getInstance();
    final a = open(prefs, 'account-a');
    final b = open(prefs, 'account-b');
    addTearDown(a.dispose);
    addTearDown(b.dispose);
    var notificationsA = 0;
    var notificationsB = 0;
    a.addListener(() => notificationsA++);
    b.addListener(() => notificationsB++);
    a.recordSession(answer('sca.tonic'));
    expect(notificationsA, 1);
    expect(notificationsB, 0);
  });

  test('signed-in binding cannot fall back to an unowned local book', () async {
    await expectLater(loadPracticeProgress(userId: ''), throwsArgumentError);
    await expectLater(
        loadPracticeProgress(userId: 'local'), throwsArgumentError);
  });
}

Map<String, dynamic> _read(String name) => Map<String, dynamic>.from(
      jsonDecode(File('assets/curriculum/$name').readAsStringSync()) as Map,
    );
