import 'dart:math';

enum MixBucket { due, recent, easy }

enum MixAction { aural, active }

class MixItem {
  const MixItem({required this.id, required this.bucket, required this.action});

  final String id;
  final MixBucket bucket;
  final MixAction action;
}

class DailyMixPlan {
  const DailyMixPlan(this.items);

  final List<MixItem> items;

  int countOf(MixBucket bucket) =>
      items.where((item) => item.bucket == bucket).length;
}

/// 12 заданий: 70% должное и ошибки, 20% недавнее, 10% лёгкое.
/// Первые 4 одного бакета, дальше чередование. Пустой бакет не заполняется выдумкой.
DailyMixPlan buildDailyMix({
  required int seed,
  required List<MixItem> pool,
  int count = 12,
}) {
  final random = Random(seed);
  final dueTarget = (count * 0.7).round();
  final recentTarget = (count * 0.2).round();
  final easyTarget = count - dueTarget - recentTarget;
  final picked = <MixItem>[
    ..._fill(pool, MixBucket.due, dueTarget, random),
    ..._fill(pool, MixBucket.recent, recentTarget, random),
    ..._fill(pool, MixBucket.easy, easyTarget, random),
  ];
  if (picked.isEmpty) return const DailyMixPlan([]);

  _keepBothActions(picked, pool);
  final blockSize = picked.take(4).length;
  final tail = picked.skip(blockSize).toList()..shuffle(random);
  return DailyMixPlan([...picked.take(blockSize), ...tail]);
}

List<MixItem> _fill(
    List<MixItem> pool, MixBucket bucket, int target, Random random) {
  final source = pool.where((item) => item.bucket == bucket).toList();
  if (source.isEmpty || target <= 0) return const [];
  return [
    for (var i = 0; i < target; i++) source[random.nextInt(source.length)]
  ];
}

void _keepBothActions(List<MixItem> picked, List<MixItem> pool) {
  final poolHasBoth = _hasBoth(pool);
  if (!poolHasBoth || _hasBoth(picked) || picked.isEmpty) return;
  final missing = picked.any((item) => item.action == MixAction.aural)
      ? MixAction.active
      : MixAction.aural;
  final index = picked.indexWhere(
    (item) => pool.any((candidate) =>
        candidate.bucket == item.bucket && candidate.action == missing),
  );
  if (index < 0) return;
  final bucket = picked[index].bucket;
  picked[index] = pool.firstWhere(
      (candidate) => candidate.bucket == bucket && candidate.action == missing);
}

bool _hasBoth(List<MixItem> items) {
  return items.any((item) => item.action == MixAction.aural) &&
      items.any((item) => item.action == MixAction.active);
}

bool pr15CanStart(bool Function(String competencyId) isMastered) =>
    isMastered('rhy.pulse_tap');

/// Пять минут из `config.daily_mix.duration_min`, если поле есть.
Duration dailyMixLimit(Map<String, dynamic> raw) {
  final mix = raw['daily_mix'];
  final minutes = mix is Map ? mix['duration_min'] : null;
  if (minutes is num && minutes > 0) {
    return Duration(minutes: minutes.toInt());
  }
  return const Duration(minutes: 5);
}

/// Промах исходного задания возвращается один раз в конец сессии.
/// Промах этого повтора новое задание не добавляет.
List<MixItem> appendSameSessionReturn({
  required List<MixItem> planned,
  required List<MixItem> running,
  required int index,
  required bool correct,
}) {
  if (correct || index < 0 || index >= planned.length) return running;
  return [...running, planned[index]];
}

/// Пул уже собранных тренажёров. Первые задания — слуховой интервал.
const appMixPool = <MixItem>[
  MixItem(id: 'PR-03', bucket: MixBucket.due, action: MixAction.aural),
  MixItem(id: 'PR-09', bucket: MixBucket.recent, action: MixAction.active),
  MixItem(id: 'PR-01', bucket: MixBucket.recent, action: MixAction.aural),
  MixItem(id: 'PR-08', bucket: MixBucket.easy, action: MixAction.active),
];

DailyMixPlan appDailyMix() => buildDailyMix(seed: 1, pool: appMixPool);

/// Должные возвраты встают в начало. Длина плана сохраняется.
DailyMixPlan placeDueReturns(DailyMixPlan plan, List<String> tags) {
  if (tags.isEmpty) return plan;
  final known = {for (final item in appMixPool) item.id: item};
  final front = [
    for (final tag in tags)
      MixItem(
        id: tag,
        bucket: MixBucket.due,
        action: known[tag]?.action ?? MixAction.aural,
      ),
  ];
  final rest = <MixItem>[];
  final skipped = <MixItem>[];
  for (final item in plan.items) {
    if (tags.contains(item.id)) {
      skipped.add(item);
    } else {
      rest.add(item);
    }
  }
  final merged = [...front, ...rest, ...skipped];
  if (merged.length <= plan.items.length) return DailyMixPlan(merged);
  return DailyMixPlan(merged.take(plan.items.length).toList());
}
