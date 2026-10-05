/// Стадия 3 PR-07 в MVP нет. Стадия 4 открывается после порога стадии 2.
bool pr07StageOpen({required int stage, required bool stage2Passed}) {
  if (stage == 3 || stage > 4) return false;
  if (stage == 4) return stage2Passed;
  return stage == 1 || stage == 2;
}

/// Исправление: средний звук с лишним полутоном возвращается к формуле.
List<int> correctThird(List<int> pitches, List<int> formula) {
  final root = pitches.reduce((a, b) => a < b ? a : b);
  return [for (final step in formula) root + step];
}
