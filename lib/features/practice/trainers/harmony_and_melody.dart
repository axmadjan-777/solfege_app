import '../../scales/utils/solfege_notes.dart';

/// Стадия 2 мелодического диктанта: только ступени тонического трезвучия, конец на тонике.
bool tonicTriadMelody(List<int> degrees) {
  if (degrees.isEmpty || degrees.last != 1) return false;
  return degrees.every((degree) => degree == 1 || degree == 3 || degree == 5);
}

/// Скачок по трезвучию: шире секунды и обе ноты — ступени I, III или V.
bool triadLeap(int fromDegree, int toDegree) {
  const chord = {1, 3, 5};
  const scale = [0, 2, 4, 5, 7, 9, 11];
  if (!chord.contains(fromDegree) || !chord.contains(toDegree)) return false;
  final span = (scale[toDegree - 1] - scale[fromDegree - 1]).abs();
  return span >= 3;
}

/// I, IV, V и vi в до мажоре. Каденция читается по двум последним функциям.
List<int> romanTriad(String roman, {int tonic = 60}) {
  const scale = [0, 2, 4, 5, 7, 9, 11];
  final degree = switch (roman) {
    'I' => 1,
    'IV' => 4,
    'V' => 5,
    'vi' => 6,
    _ => 0,
  };
  if (degree == 0) return const [];
  final root = tonic + scale[degree - 1];
  final quality = switch (roman) {
    'vi' => [0, 3, 7],
    _ => [0, 4, 7],
  };
  return [for (final step in quality) root + step];
}

String cadenceType(List<String> romans) {
  if (romans.length < 2) return '';
  final penultimate = romans[romans.length - 2];
  final last = romans.last;
  if (penultimate == 'V' && last == 'I') return 'authentic';
  if (penultimate == 'IV' && last == 'I') return 'plagal';
  if (penultimate == 'V' && last == 'vi') return 'deceptive';
  if (last == 'V') return 'half';
  return '';
}

int bassOf(List<int> chord) => chord.reduce((a, b) => a < b ? a : b);

/// Пение без микрофона: самоотчёт не ставит mastered и не сравнивает высоту.
bool singGrantsMastered(String selfReport) => false;

String singPrompt(String task) => task == 'tonic' ? 'Спой тонику' : 'Спой ступень';

/// Трезвучия натурального и гармонического минора.
const naturalMinorTriads = ['minor', 'dim', 'major', 'minor', 'minor', 'major', 'major'];
const harmonicMinorTriads = ['minor', 'dim', 'major', 'minor', 'major', 'major', 'dim'];

String syllableOfDegree(int degree) => SolfegeNotes.naturalNames[degree - 1];
