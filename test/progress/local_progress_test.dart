import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:solfege_app/features/curriculum/data/curriculum_asset_source.dart';
import 'package:solfege_app/features/curriculum/data/curriculum_catalog.dart';
import 'package:solfege_app/features/practice/progress/account_progress_store.dart';
import 'package:solfege_app/features/practice/progress/clock.dart';
import 'package:solfege_app/features/practice/progress/progress_store.dart';
import 'package:solfege_app/features/practice/widgets/account_progress_notice.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late CurriculumCatalog catalog;
  late SharedPreferences preferences;
  final answeredAt = DateTime.utc(2026, 11, 11, 9);

  setUpAll(() async {
    catalog = await const CurriculumAssetSource().load();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();
  });

  AccountProgressStore openStore({
    String userId = 'qa01-local-user',
    Future<bool> Function(String key, String value)? writeString,
  }) {
    var nextWrite = 0;
    final store = AccountProgressStore(
      preferences: preferences,
      userId: userId,
      currentUserId: () => userId,
      clock: FixedClock(answeredAt),
      rules: catalog.config.masteryRules,
      newWriteId: () => 'qa01-write-${++nextWrite}',
      writeString: writeString,
    );
    addTearDown(store.dispose);
    return store;
  }

  test('recorded answers survive closing and reopening local progress',
      () async {
    final store = openStore();
    store.recordSession(SessionDraft(
      competencyId: 'int.thirds',
      sessionId: 'qa01-session',
      correct: const [true, false],
      policy: catalog.config.policy('RP-knowledge'),
      tonality: 'C',
    ));
    await store.flushLocal();
    store.close();

    // Read the platform store again, rather than reusing only its client cache.
    await preferences.reload();
    final reopened = openStore();
    expect(reopened.book.attempts.map((attempt) => attempt.isCorrect),
        [true, false]);
    expect(reopened.book.attempts.map((attempt) => attempt.competencyId),
        ['int.thirds', 'int.thirds']);
    expect(reopened.book.attempts.map((attempt) => attempt.createdAt),
        [answeredAt, answeredAt]);
  });

  testWidgets('failed local write is reported to the caller and on screen',
      (tester) async {
    // Only the disk boundary fails; the real store and notice handle the error.
    final store = openStore(
      userId: 'qa01-write-failure-user',
      writeString: (key, value) async => false,
    );
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: AccountProgressNotice(store: store)),
    ));

    store.recordSession(SessionDraft(
      competencyId: 'int.thirds',
      sessionId: 'qa01-failed-session',
      correct: const [true],
      policy: catalog.config.policy('RP-knowledge'),
      tonality: 'C',
    ));
    await expectLater(store.flushLocal(), throwsStateError);
    await tester.pump();

    expect(store.state, AccountSyncState.error);
    expect(
      find.text(
          'Не удалось сохранить прогресс на устройстве. Повторите сохранение.'),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
