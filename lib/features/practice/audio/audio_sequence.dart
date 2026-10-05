import 'dart:math';

/// Одинаковая громкость сравниваемых сигналов. Часть 5.
const practiceAudioVolume = 0.35;

/// Событие, которое плеер умеет сыграть. Тесты смотрят на список, не на WAV.
sealed class AudioEvent {
  const AudioEvent();
}

class ChordEvent extends AudioEvent {
  const ChordEvent(this.midi, {this.durationMs = 700, this.volume = practiceAudioVolume});

  final List<int> midi;
  final int durationMs;
  final double volume;
}

class NoteEvent extends AudioEvent {
  const NoteEvent(this.midi, {this.durationMs = 1000, this.volume = practiceAudioVolume});

  final int midi;
  final int durationMs;
  final double volume;
}

class RestEvent extends AudioEvent {
  const RestEvent(this.durationMs);

  final int durationMs;
}

class AudioSequence {
  const AudioSequence(this.events);

  final List<AudioEvent> events;
}

/// Каденция До мажора I–IV–V–I, по 4 голоса (внутри 3–5), затем пауза и ступень.
class TonalPrompt {
  const TonalPrompt._();

  static const cadenceI = [48, 52, 55, 60];
  static const cadenceIV = [48, 53, 57, 60];
  static const cadenceV = [50, 55, 59, 62];

  static AudioSequence cMajorDegree({required int seed, int restMs = 500}) {
    final midi = 60 + Random(seed).nextInt(13);
    return AudioSequence([
      const ChordEvent(cadenceI),
      const ChordEvent(cadenceIV),
      const ChordEvent(cadenceV),
      const ChordEvent(cadenceI),
      RestEvent(restMs),
      NoteEvent(midi),
    ]);
  }

  /// Повторная ошибка: верно → ответ → верно, одна громкость.
  static AudioSequence comparative({required int correctMidi, required int chosenMidi}) {
    return AudioSequence([
      NoteEvent(correctMidi),
      NoteEvent(chosenMidi),
      NoteEvent(correctMidi),
    ]);
  }
}

/// Пять правил защиты от абсолютной высоты, не выходя за диапазон стадии.
class AbsolutePitchGuard {
  const AbsolutePitchGuard._();

  static int registerOf(int midi) => midi < 60 ? 0 : (midi < 72 ? 1 : 2);

  static int nextStimulus({
    required Random random,
    required int low,
    required int high,
    required int consecutiveCorrectInRegister,
    int? lastRegister,
  }) {
    final span = high - low;
    final first = low + random.nextInt(span + 1);
    if (consecutiveCorrectInRegister < 2 || span < 12) return first;
    final forbidden = lastRegister ?? registerOf(first);
    for (var attempt = 0; attempt < 24; attempt++) {
      final candidate = low + random.nextInt(span + 1);
      if (registerOf(candidate) != forbidden) return candidate;
    }
    return registerOf(low) == forbidden ? high : low;
  }

  /// Слуховое задание не показывает ноты на первом проигрывании.
  static bool showNotationOnFirstPlay() => false;

  /// Первые ритмические задания не быстрее 100 BPM.
  static int introRhythmBpm(int requested) => requested > 100 ? 100 : requested;
}

/// Аудио вне MVP не загружается, даже если id есть в манифесте.
class AudioBankPolicy {
  const AudioBankPolicy._();

  static const excluded = {'AU-11', 'AU-13', 'AU-14', 'AU-15'};

  static bool allows(String id) => !excluded.contains(id);
}
