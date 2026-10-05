final _pitchClass = {'C': 0, 'D': 2, 'E': 4, 'F': 5, 'G': 7, 'A': 9, 'B': 11};

final _syllable = {
  'C': 'До',
  'D': 'Ре',
  'E': 'Ми',
  'F': 'Фа',
  'G': 'Соль',
  'A': 'Ля',
  'B': 'Си',
};

/// C4 = 60. Диез и бемоль одного звука совпадают: Bb4 и A#4.
int? midiOf(String note) {
  final match = RegExp(r'^([A-G])([#b]?)(\d)$').firstMatch(note.trim());
  if (match == null) return null;
  final base = _pitchClass[match.group(1)];
  if (base == null) return null;
  var pitch = base;
  final accidental = match.group(2);
  if (accidental == '#') pitch += 1;
  if (accidental == 'b') pitch -= 1;
  final octave = int.parse(match.group(3)!);
  return (octave + 1) * 12 + pitch;
}

bool samePitch(String a, String b) {
  final left = midiOf(a);
  final right = midiOf(b);
  return left != null && left == right;
}

String shortName(String note) {
  final match = RegExp(r'^([A-G])([#b]?)').firstMatch(note.trim());
  if (match == null) return note;
  final syllable = _syllable[match.group(1)] ?? match.group(1)!;
  return switch (match.group(2)) {
    '#' => '$syllable-диез',
    'b' => '$syllable-бемоль',
    _ => syllable,
  };
}

String currentNoteLabel(String note) => '${shortName(note)} ($note)';

String keyCaption(String note) => '${shortName(note).toLowerCase()} / $note';

/// Имя файла без `#`: на вебе решётка обрывает адрес ассета.
String noteAssetPath(String note) => 'audio/${note.replaceAll('#', 's')}.mp3';
