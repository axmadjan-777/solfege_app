// Deliberate fixture update:
// flutter test tool/browser/generate_progress_fixture.dart
// The seed uses the same rules and serializer as production and masters exactly
// the prerequisite of L03-04, never all gates or the target competency.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:solfege_app/features/curriculum/data/curriculum_asset_source.dart';
import 'package:solfege_app/features/practice/progress/attempt.dart';
import 'package:solfege_app/features/practice/progress/clock.dart';
import 'package:solfege_app/features/practice/progress/progress_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('serialize only the L03-04 prerequisite using production rules',
      () async {
    final catalog = await const CurriculumAssetSource().load();
    final clock = FixedClock(DateTime.utc(2026, 11, 1, 9));
    final store = MemoryProgressStore(
      clock: clock,
      rules: catalog.config.masteryRules,
      userId: '11111111-1111-4111-8111-111111111111',
    );
    const competency = 'not.anchors_treble';
    final lesson = catalog.findLesson('L03-03')!;
    final policy = catalog.config.policy(lesson.coldReviewPolicyId);
    store.recordSession(SessionDraft(
      competencyId: competency,
      sessionId: 'qa-prerequisite-training',
      correct: List.filled(catalog.config.masteryRules.immediateWindow, true),
      policy: policy,
      tonality: 'C',
    ));
    clock.advance(const Duration(hours: 21));
    store.recordSession(SessionDraft(
      competencyId: competency,
      sessionId: 'qa-prerequisite-cold',
      correct: List.filled(catalog.config.masteryRules.delayedMinItems, true),
      policy: policy,
      tonality: 'G',
      coldReview: true,
    ));
    expect(store.book.competencies.keys, [competency]);
    expect(store.snapshot(competency).status, CompetencyStatus.mastered);
    final output = File('tool/browser/fixtures/note_anchors_mastered.json');
    await output.parent.create(recursive: true);
    await output.writeAsString(
        '${const JsonEncoder.withIndent('  ').convert(store.book.toJson())}\n');
  });
}
