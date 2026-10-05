/// Знак при ноте меняет звучание на полутон. Бекар отменяет диез ключа.
int soundingMidi(int writtenMidi, {required String accidental, bool keyRaises = false}) {
  final shift = switch (accidental) {
    'sharp' => 1,
    'flat' => -1,
    'natural' => 0,
    _ => keyRaises ? 1 : 0,
  };
  return writtenMidi + shift;
}

/// Лига складывает длительности. Точка увеличивает длительность в полтора раза.
double tied(List<double> beats) => beats.fold(0, (sum, beat) => sum + beat);

double dotted(double beats) => beats * 1.5;
