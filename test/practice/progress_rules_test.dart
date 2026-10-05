import 'dart:convert';
import 'dart:io';

import 'package:solfege_app/features/curriculum/data/curriculum_catalog.dart';
import 'package:solfege_app/features/curriculum/models/curriculum_config.dart';
import 'package:solfege_app/features/practice/progress/attempt.dart';
import 'package:solfege_app/features/practice/progress/clock.dart';
import 'package:solfege_app/features/practice/progress/progress_rules.dart';
import 'package:solfege_app/features/practice/progress/progress_store.dart';
import 'package:test/test.dart';

void main() {
  late CurriculumCatalog catalog;
  late MasteryRules rules;
  late ReviewPolicy aural;
  late FixedClock clock;
  late MemoryProgressStore store;

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
    rules = catalog.config.masteryRules;
    aural = catalog.config.policy('RP-aural');
    clock = FixedClock(DateTime.utc(2026, 10, 4, 12));
    store = MemoryProgressStore(clock: clock, rules: rules);
  });

  test(
      'twelve answers at 85 percent become provisionally passed and not mastered',
      () {
    store.recordSession(
      _session(
        id: 'window',
        correct: [...List<bool>.filled(11, true), false],
        policy: aural,
      ),
    );

    final snapshot = store.snapshot('ear.degree.major.1');
    expect(snapshot.status, CompetencyStatus.provisionallyPassed);
    expect(snapshot.status, isNot(CompetencyStatus.mastered));
  });

  test('a perfect session still cannot grant mastered', () {
    store.recordSession(_session(
        id: 'perfect', correct: List<bool>.filled(12, true), policy: aural));

    expect(store.snapshot('ear.degree.major.1').status,
        CompetencyStatus.provisionallyPassed);
  });

  test('cold review at least 20 hours later grants mastered', () {
    store.recordSession(_session(
        id: 'learn', correct: List<bool>.filled(12, true), policy: aural));
    clock.advance(const Duration(hours: 20));
    store.recordSession(
      _session(
        id: 'cold',
        correct: List<bool>.filled(4, true),
        policy: aural,
        coldReview: true,
      ),
    );

    expect(
        store.snapshot('ear.degree.major.1').status, CompetencyStatus.mastered);
  });

  test('cold review in the same hour does not grant mastered', () {
    store.recordSession(_session(
        id: 'learn', correct: List<bool>.filled(12, true), policy: aural));
    store.recordSession(
      _session(
          id: 'cold-soon',
          correct: List<bool>.filled(4, true),
          policy: aural,
          coldReview: true),
    );

    expect(store.snapshot('ear.degree.major.1').status,
        CompetencyStatus.provisionallyPassed);
  });

  test('one miss in a due cold review returns the competency to practice', () {
    store.recordSession(_session(
        id: 'learn', correct: List<bool>.filled(12, true), policy: aural));
    final marked = store.snapshot('ear.degree.major.1').provisionalAt;
    clock.advance(const Duration(hours: 20));
    store.recordSession(
      _session(
        id: 'cold-miss',
        correct: const [true, true, true, false],
        policy: aural,
        coldReview: true,
      ),
    );

    final snapshot = store.snapshot('ear.degree.major.1');
    expect(snapshot.status, CompetencyStatus.needsReview);
    expect(snapshot.provisionalAt, isNull);
    expect(marked, isNotNull);
  });

  test('the next passing window starts a new 20 hour wait', () {
    store.recordSession(_session(
        id: 'learn', correct: List<bool>.filled(12, true), policy: aural));
    final firstMark = store.snapshot('ear.degree.major.1').provisionalAt;
    clock.advance(const Duration(hours: 20));
    store.recordSession(
      _session(
          id: 'cold-miss',
          correct: const [true, true, true, false],
          policy: aural,
          coldReview: true),
    );
    clock.advance(const Duration(hours: 1));
    store.recordSession(
        _session(id: 'again', correct: const [true], policy: aural));

    final restored = store.snapshot('ear.degree.major.1');
    expect(restored.status, CompetencyStatus.provisionallyPassed);
    expect(restored.provisionalAt, clock.now());
    expect(restored.provisionalAt, isNot(firstMark));

    store.recordSession(_session(
        id: 'cold-soon',
        correct: List<bool>.filled(4, true),
        policy: aural,
        coldReview: true));
    expect(store.snapshot('ear.degree.major.1').status,
        CompetencyStatus.provisionallyPassed);

    clock.advance(const Duration(hours: 20));
    store.recordSession(_session(
        id: 'cold-ok',
        correct: List<bool>.filled(4, true),
        policy: aural,
        coldReview: true));
    expect(
        store.snapshot('ear.degree.major.1').status, CompetencyStatus.mastered);
  });

  test('accuracy below 0.6 on the last six answers demotes to needs review',
      () {
    store.recordSession(_session(
        id: 'learn', correct: List<bool>.filled(12, true), policy: aural));
    store.recordSession(
      _session(
          id: 'slip',
          correct: [true, true, false, false, false, false],
          policy: aural),
    );

    expect(store.snapshot('ear.degree.major.1').status,
        CompetencyStatus.needsReview);
  });

  test('RP-aural transfer walks interval days and an error steps back', () {
    expect(aural.intervalDays, [1, 2, 5, 10, 21]);

    store.recordSession(
      _session(
          id: 'move',
          correct: List<bool>.filled(4, true),
          policy: aural,
          transfer: true),
    );
    expect(store.snapshot('ear.degree.major.1').intervalStep, 1);
    expect(store.snapshot('ear.degree.major.1').dueAt,
        clock.now().add(const Duration(days: 2)));

    store.recordSession(_session(
        id: 'miss', correct: [false, false, false, false], policy: aural));
    expect(store.snapshot('ear.degree.major.1').intervalStep, 0);
    expect(store.snapshot('ear.degree.major.1').dueAt,
        clock.now().add(const Duration(days: 1)));
  });

  test('stability records three spaced successes with one in another key', () {
    store.recordSession(_session(
        id: 's1',
        correct: List<bool>.filled(4, true),
        policy: aural,
        tonality: 'C'));
    clock.advance(const Duration(hours: 20));
    store.recordSession(_session(
        id: 's2',
        correct: List<bool>.filled(4, true),
        policy: aural,
        tonality: 'C'));
    expect(store.snapshot('ear.degree.major.1').stability.reached, isFalse);
    clock.advance(const Duration(hours: 20));
    store.recordSession(_session(
        id: 's3',
        correct: List<bool>.filled(4, true),
        policy: aural,
        tonality: 'G'));

    expect(store.snapshot('ear.degree.major.1').stability.reached, isTrue);
    expect(store.snapshot('ear.degree.major.1').status,
        isNot(CompetencyStatus.mastered));
  });

  test('a lesson stays closed until the prerequisite competency is mastered',
      () {
    final next = catalog.lesson('L00-02');
    expect(
      isLessonOpen(lesson: next, catalog: catalog, isMastered: (_) => false),
      isFalse,
    );
    expect(
      isLessonOpen(
        lesson: next,
        catalog: catalog,
        isMastered: (id) => id == 'snd.tone_vs_noise',
      ),
      isTrue,
    );
    expect(
      isLessonOpen(
          lesson: catalog.lesson('L00-01'),
          catalog: catalog,
          isMastered: (_) => false),
      isTrue,
    );
  });

  test('progress book keeps user id and round-trips through json', () {
    store.recordSession(
      _session(
          id: 'tag', correct: [false], policy: aural, errorTag: 'degree.4'),
    );

    expect(store.book.userId, 'local');
    expect(store.openErrorTags(), ['degree.4']);
    final restored = ProgressBook.fromJson(
        jsonDecode(jsonEncode(store.book.toJson())) as Map<String, dynamic>);
    expect(restored.attempts.single.errorTag, 'degree.4');
    expect(restored.attempts.single.itemSignature, isNotEmpty);
  });
}

SessionDraft _session({
  required String id,
  required List<bool> correct,
  required ReviewPolicy policy,
  bool coldReview = false,
  bool transfer = false,
  String tonality = 'C',
  String errorTag = 'degree.2',
}) {
  return SessionDraft(
    competencyId: 'ear.degree.major.1',
    sessionId: id,
    correct: correct,
    policy: policy,
    tonality: tonality,
    coldReview: coldReview,
    transfer: transfer,
    errorTag: errorTag,
  );
}

Map<String, dynamic> _read(String name) {
  return Map<String, dynamic>.from(
      jsonDecode(File('assets/curriculum/$name').readAsStringSync()) as Map);
}
