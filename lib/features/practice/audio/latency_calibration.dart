/// Профиль задержки. Поле совпадает с именем из части 5.
class AudioProfile {
  const AudioProfile({this.audioLatencyOffsetMs = 0});

  final int audioLatencyOffsetMs;

  AudioProfile withOffset(int milliseconds) => AudioProfile(audioLatencyOffsetMs: milliseconds);
}

/// Восемь тапов вместе с метрономом. Слишком большой разброс — калибровка не удалась.
class LatencyCalibration {
  const LatencyCalibration();

  static const tapsRequired = 8;
  static const maxSpreadMs = 80;

  /// Медиана восьми дельт «тап минус щелчок», либо null.
  int? offsetMs(List<int> tapMinusClickMs) {
    if (tapMinusClickMs.length != tapsRequired) return null;
    final sorted = [...tapMinusClickMs]..sort();
    if (sorted.last - sorted.first > maxSpreadMs) return null;
    return ((sorted[3] + sorted[4]) / 2).round();
  }
}

/// Куда уходит сессия, если калибровка T09 не удалась.
/// Сетка T08 появится в итерации уровня 2; контракт уже называется здесь.
class TapFallback {
  const TapFallback();

  static const templates = ['T02', 'T08'];

  AudioProfile apply(AudioProfile profile, List<int> tapMinusClickMs) {
    final offset = const LatencyCalibration().offsetMs(tapMinusClickMs);
    if (offset == null) return profile;
    return profile.withOffset(offset);
  }

  bool failed(List<int> tapMinusClickMs) => const LatencyCalibration().offsetMs(tapMinusClickMs) == null;
}
