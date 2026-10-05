import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solfege_app/features/practice/progress/clock.dart';
import 'package:solfege_app/features/practice/progress/error_return.dart';
import 'package:solfege_app/features/practice/screens/daily_mix_screen.dart';
import 'package:solfege_app/features/practice/trainers/daily_mix.dart';

void main() {
  const pool = [
    MixItem(id: 'PR-01', bucket: MixBucket.due, action: MixAction.aural),
    MixItem(id: 'PR-09', bucket: MixBucket.due, action: MixAction.active),
    MixItem(id: 'PR-03', bucket: MixBucket.recent, action: MixAction.aural),
    MixItem(id: 'PR-08', bucket: MixBucket.easy, action: MixAction.active),
  ];

  test(
      'twelve items follow 70/20/10, start as a block, and include both actions',
      () {
    final plan = buildDailyMix(seed: 3, pool: pool);

    expect(plan.items, hasLength(12));
    expect(plan.countOf(MixBucket.due), 8);
    expect(plan.countOf(MixBucket.recent), 2);
    expect(plan.countOf(MixBucket.easy), 2);
    expect(plan.items.take(4).every((item) => item.bucket == MixBucket.due),
        isTrue);
    expect(plan.items.any((item) => item.action == MixAction.aural), isTrue);
    expect(plan.items.any((item) => item.action == MixAction.active), isTrue);
    expect(
        plan.items.every((item) => pool.any((source) => source.id == item.id)),
        isTrue);
  });

  test('an aural-only pool does not invent an active item', () {
    final plan = buildDailyMix(
      seed: 1,
      pool: const [
        MixItem(id: 'PR-01', bucket: MixBucket.due, action: MixAction.aural)
      ],
    );

    expect(plan.items.every((item) => item.action == MixAction.aural), isTrue);
    expect(plan.items.every((item) => item.id == 'PR-01'), isTrue);
  });

  test('a miss returns once at the end and a second miss does not', () {
    const planned = [
      MixItem(id: 'PR-03', bucket: MixBucket.due, action: MixAction.aural),
      MixItem(id: 'PR-08', bucket: MixBucket.easy, action: MixAction.active),
    ];
    final afterFirst = appendSameSessionReturn(
      planned: planned,
      running: planned,
      index: 0,
      correct: false,
    );
    expect(afterFirst.map((item) => item.id), ['PR-03', 'PR-08', 'PR-03']);
    final afterReturn = appendSameSessionReturn(
      planned: planned,
      running: afterFirst,
      index: 2,
      correct: false,
    );
    expect(afterReturn, hasLength(3));
    final kept = appendSameSessionReturn(
      planned: planned,
      running: planned,
      index: 0,
      correct: true,
    );
    expect(kept, hasLength(2));
  });

  test('the mix stays closed until the pulse lesson is mastered', () {
    expect(pr15CanStart((id) => id == 'rhy.pulse_tap'), isTrue);
    expect(pr15CanStart((_) => false), isFalse);
  });

  testWidgets('the summary shows the real bucket counts', (tester) async {
    final plan = buildDailyMix(seed: 3, pool: pool);
    await tester.pumpWidget(MaterialApp(home: DailyMixScreen(plan: plan)));

    expect(find.text('Заданий: 12'), findsOneWidget);
    expect(
        find.text('Должное: ${plan.countOf(MixBucket.due)}'), findsOneWidget);
    expect(find.text('Недавнее: ${plan.countOf(MixBucket.recent)}'),
        findsOneWidget);
    expect(
        find.text('Лёгкое: ${plan.countOf(MixBucket.easy)}'), findsOneWidget);
    expect(find.text('Начать'), findsNothing);
  });

  test('the app mix starts with the aural interval', () {
    final plan = appDailyMix();
    expect(plan.items, hasLength(12));
    expect(plan.items.first.id, 'PR-03');
    expect(plan.items.first.action, MixAction.aural);
    expect(plan.items.any((item) => item.action == MixAction.active), isTrue);
  });

  testWidgets('each planned item is answered before the total', (tester) async {
    const plan = DailyMixPlan([
      MixItem(id: 'PR-03', bucket: MixBucket.due, action: MixAction.aural),
      MixItem(id: 'PR-08', bucket: MixBucket.easy, action: MixAction.active),
    ]);
    await tester.pumpWidget(
      MaterialApp(
        home: DailyMixScreen(
          plan: plan,
          taskBuilder: (item, onAnswered) => Scaffold(
            body: FilledButton(
              onPressed: () => onAnswered(item.id == 'PR-03'),
              child: Text(item.id),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Заданий: 2'), findsOneWidget);
    await tester.tap(find.text('Начать'));
    await tester.pump();
    await tester.tap(find.text('PR-03'));
    await tester.pump();
    expect(find.text('Дальше'), findsOneWidget);
    await tester.tap(find.text('Дальше'));
    await tester.pump();
    await tester.tap(find.text('PR-08'));
    await tester.pump();
    expect(find.text('Дальше'), findsOneWidget);
    await tester.tap(find.text('Дальше'));
    await tester.pump();
    expect(find.text('Повтор ошибки'), findsOneWidget);
    expect(find.text('PR-08'), findsOneWidget);
    await tester.tap(find.text('PR-08'));
    await tester.pump();
    expect(find.text('Итог'), findsOneWidget);
    expect(find.text('Дальше'), findsNothing);
    await tester.tap(find.text('Итог'));
    await tester.pump();
    expect(find.text('Итог: верно 1 из 3'), findsOneWidget);
    expect(find.text('Заданий: 2'), findsOneWidget);
  });

  test('a due return leads the next mix and an early clock does not', () {
    final at = DateTime.utc(2026, 10, 5, 8);
    final scheduled = scheduleNextDay(
      current: const [],
      tag: 'PR-08',
      at: at,
    );
    expect(scheduled.single.dueAt, DateTime.utc(2026, 10, 6, 8));
    expect(
      dueReturnTags(
          scheduled: scheduled, now: at.add(const Duration(hours: 23))),
      isEmpty,
    );
    final due = dueReturnTags(
      scheduled: scheduled,
      now: at.add(const Duration(days: 1)),
    );
    expect(due, ['PR-08']);
    final plan = placeDueReturns(appDailyMix(), due);
    expect(plan.items, hasLength(12));
    expect(plan.items.first.id, 'PR-08');
    expect(plan.items.first.bucket, MixBucket.due);
    final base = appDailyMix();
    expect(identical(placeDueReturns(base, const []), base), isTrue);
  });

  test('a successful return waits three days and a miss stays on tomorrow', () {
    final at = DateTime.utc(2026, 10, 5, 8);
    final scheduled = scheduleAfter(
      current: scheduleNextDay(current: const [], tag: 'PR-08', at: at),
      tag: 'PR-08',
      at: at.add(const Duration(days: 1)),
      days: 3,
    );
    expect(scheduled.single.dueAt, DateTime.utc(2026, 10, 9, 8));
    expect(
      dueReturnTags(
        scheduled: scheduled,
        now: at.add(const Duration(days: 3)),
      ),
      isEmpty,
    );
    expect(
      dueReturnTags(
        scheduled: scheduled,
        now: at.add(const Duration(days: 4)),
      ),
      ['PR-08'],
    );
    expect(
        errorReturnSuccessDays(const {
          'error_queue': {'after_success_days': 3}
        }),
        3);
    expect(returnGapLabel(1), 'Через 1 день');
    expect(returnGapLabel(3), 'Через 3 дня');
    expect(returnGapLabel(5), 'Через 5 дней');
    expect(returnGapLabel(11), 'Через 11 дней');
  });

  test('the mix limit reads duration_min', () {
    expect(
      dailyMixLimit(const {
        'daily_mix': {'duration_min': 5}
      }),
      const Duration(minutes: 5),
    );
    expect(dailyMixLimit(const {}), const Duration(minutes: 5));
  });

  testWidgets('five minutes ends the mix before the next item', (tester) async {
    final clock = FixedClock(DateTime.utc(2026, 10, 5, 8));
    await tester.pumpWidget(
      MaterialApp(
        home: DailyMixScreen(
          plan: const DailyMixPlan([
            MixItem(
                id: 'PR-03', bucket: MixBucket.due, action: MixAction.aural),
            MixItem(
                id: 'PR-08', bucket: MixBucket.easy, action: MixAction.active),
          ]),
          clock: clock,
          sessionLimit: const Duration(minutes: 5),
          taskBuilder: (item, onAnswered) => Scaffold(
            body: FilledButton(
              onPressed: () => onAnswered(true),
              child: Text(item.id),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Начать'));
    await tester.pump();
    await tester.tap(find.text('PR-03'));
    await tester.pump();
    clock.advance(const Duration(minutes: 5));
    await tester.tap(find.text('Дальше'));
    await tester.pump();
    expect(find.text('Время вышло'), findsOneWidget);
    expect(find.text('Итог: верно 1 из 1'), findsOneWidget);
    expect(find.text('PR-08'), findsNothing);
  });

  testWidgets('four minutes still opens the next item', (tester) async {
    final clock = FixedClock(DateTime.utc(2026, 10, 5, 8));
    await tester.pumpWidget(
      MaterialApp(
        home: DailyMixScreen(
          plan: const DailyMixPlan([
            MixItem(
                id: 'PR-03', bucket: MixBucket.due, action: MixAction.aural),
            MixItem(
                id: 'PR-08', bucket: MixBucket.easy, action: MixAction.active),
          ]),
          clock: clock,
          sessionLimit: const Duration(minutes: 5),
          taskBuilder: (item, onAnswered) => Scaffold(
            body: FilledButton(
              onPressed: () => onAnswered(true),
              child: Text(item.id),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Начать'));
    await tester.pump();
    await tester.tap(find.text('PR-03'));
    await tester.pump();
    clock.advance(const Duration(minutes: 4));
    await tester.tap(find.text('Дальше'));
    await tester.pump();
    expect(find.text('PR-08'), findsOneWidget);
    expect(find.text('Время вышло'), findsNothing);
  });

  testWidgets('answering the same-session return schedules tomorrow',
      (tester) async {
    final seen = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: DailyMixScreen(
          plan: const DailyMixPlan([
            MixItem(
                id: 'PR-08', bucket: MixBucket.due, action: MixAction.active),
          ]),
          onSameSessionReturn: seen.add,
          taskBuilder: (item, onAnswered) => Scaffold(
            body: FilledButton(
              onPressed: () => onAnswered(false),
              child: Text(item.id),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Начать'));
    await tester.pump();
    await tester.tap(find.text('PR-08'));
    await tester.pump();
    expect(seen, isEmpty);
    await tester.tap(find.text('Дальше'));
    await tester.pump();
    expect(find.text('Повтор ошибки'), findsOneWidget);
    await tester.tap(find.text('PR-08'));
    await tester.pump();
    await tester.tap(find.text('Итог'));
    await tester.pump();
    expect(seen, ['PR-08']);
    expect(find.text('Завтра: PR-08'), findsOneWidget);
  });

  testWidgets('a correct due return waits three days', (tester) async {
    final seen = <(String, bool)>[];
    await tester.pumpWidget(
      MaterialApp(
        home: DailyMixScreen(
          plan: const DailyMixPlan([
            MixItem(
                id: 'PR-08', bucket: MixBucket.due, action: MixAction.active),
          ]),
          dueNow: const {'PR-08'},
          successDays: 3,
          onDueAnswer: (tag, correct) => seen.add((tag, correct)),
          taskBuilder: (item, onAnswered) => Scaffold(
            body: FilledButton(
              onPressed: () => onAnswered(true),
              child: Text(item.id),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Начать'));
    await tester.pump();
    await tester.tap(find.text('PR-08'));
    await tester.pump();
    await tester.tap(find.text('Итог'));
    await tester.pump();
    expect(seen, [('PR-08', true)]);
    expect(find.text('Через 3 дня: PR-08'), findsOneWidget);
    expect(find.text('Завтра: PR-08'), findsNothing);
  });
}
