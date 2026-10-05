import '../audio/audio_sequence.dart';

/// Допуск попадания в долю. Офсет калибровки вычитается из тапа.
class OnsetJudge {
  const OnsetJudge._();

  static int toleranceMs(int stage) {
    if (stage <= 1) return 120;
    if (stage >= 5) return 90;
    return 110;
  }

  static bool hit({
    required int tapMs,
    required int clickMs,
    required int latencyOffsetMs,
    required int toleranceMs,
  }) {
    return (tapMs - clickMs - latencyOffsetMs).abs() <= toleranceMs;
  }

  static int cappedTempo(int bpm) => bpm > 100 ? 100 : bpm;
}

/// Стадия PR-09 стартует, когда освоены три урока MVP. L07-01 не входит в замок.
bool pr09CanStart(bool Function(String competencyId) isMastered) {
  return isMastered('rhy.pulse_tap') && isMastered('rhy.beat_tempo') && isMastered('rhy.eighths');
}

/// AU-04 — синтетический клик, без чужого файла.
AudioSequence metronomeClicks({required int bpm, int beats = 4}) {
  final tempo = OnsetJudge.cappedTempo(bpm);
  final gap = (60000 / tempo).round();
  return AudioSequence([
    for (var i = 0; i < beats; i++) ...[
      const NoteEvent(37, durationMs: 40),
      RestEvent(gap),
    ],
  ]);
}
