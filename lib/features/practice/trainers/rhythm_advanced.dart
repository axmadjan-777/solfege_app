/// Шестнадцатая — четверть четверти. Три триольных восьмых занимают одну четверть,
/// три обычные восьмые длиннее. 6/8 и 3/4 содержат по шесть восьмых, но группируются по-разному.
const double sixteenth = 0.25;
const double eighth = 0.5;
const double quarter = 1;

double dottedValue(double beats) => beats * 1.5;

bool eighthTripletFillsOneQuarter() => (eighthTriplet * 3 - quarter).abs() < 1e-9;

const double eighthTriplet = 1 / 3;

int eighthsInMeter(String meter) {
  return switch (meter) {
    '6/8' => 6,
    '3/4' => 6,
    '5/4' => 10,
    '7/8' => 7,
    _ => 0,
  };
}

List<int> beatGroups(String meter) {
  return switch (meter) {
    '6/8' => const [3, 3],
    '3/4' => const [2, 2, 2],
    '5/4' => const [3, 2],
    '7/8' => const [2, 2, 3],
    _ => const [],
  };
}

/// Синкопа: акцент на слабой восьмой, когда предыдущая сильная доля пустая.
bool isSyncopated(List<bool> eighthAccents) {
  for (final off in [1, 3, 5, 7]) {
    if (off < eighthAccents.length && eighthAccents[off] && !eighthAccents[off - 1]) return true;
  }
  return false;
}
