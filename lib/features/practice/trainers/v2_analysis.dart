/// Нота мелодии входит в аккорд, если совпадает с ним по звукоряду, в любой октаве.
bool noteBelongsToChord(int melodyMidi, List<int> chord) {
  return chord.any((pitch) => pitch % 12 == melodyMidi % 12);
}

/// Модуляция есть, когда конечная тоника — другая высота, чем начальная.
bool hasModulated(int startTonic, int endTonic) => startTonic % 12 != endTonic % 12;

int tonicAFifthUp(int tonic) => tonic + 7;

/// Первое чтение: до попытки повтора нет. Эталон показывают после ответа.
class FirstReading {
  const FirstReading();

  int replaysBeforeAttempt(int attemptsMade) => attemptsMade == 0 ? 0 : 1;

  bool revealOnlyAfterAttempt(int attemptsMade) => attemptsMade > 0;
}

/// Пение интервала: ожидаемая высота известна для показа после попытки.
/// Записанный звук не сравнивается и mastered не ставится.
int expectedSungMidi(int startMidi, int semitones) => startMidi + semitones;

bool singAttemptGrantsMastered() => false;
