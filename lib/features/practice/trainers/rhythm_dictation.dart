/// Длительности в четвертях. Сумма такта 4/4 равна 4, такта 3/4 равна 3.
class RhythmDictation {
  const RhythmDictation._();

  static const beats = {
    'целая': 4.0,
    'половинная': 2.0,
    'четверть': 1.0,
    'восьмая': 0.5,
    'четвертная пауза': 1.0,
    'восьмая пауза': 0.5,
  };

  static const stimulusReplays = 3;

  static double sum(List<String> tokens) {
    return tokens.fold(0, (total, token) => total + (beats[token] ?? 0));
  }

  static bool barFits(List<String> tokens, {required int beatsInBar}) {
    return sum(tokens) == beatsInBar;
  }

  /// Номер первого такта, который не сошёлся. Нумерация с 1. null — все верны.
  static int? wrongBar(List<List<String>> bars, {required List<int> beatsInBar}) {
    for (var i = 0; i < bars.length; i++) {
      if (!barFits(bars[i], beatsInBar: beatsInBar[i])) return i + 1;
    }
    return null;
  }
}
