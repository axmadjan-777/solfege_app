/// Russian solfege note naming for UI display.
abstract final class SolfegeNotes {
  static const naturalNames = ['до', 'ре', 'ми', 'фа', 'соль', 'ля', 'си'];
  static const naturalPitchClasses = [0, 2, 4, 5, 7, 9, 11];

  static const sharpNames = [
    'до',
    'до-диез',
    'ре',
    'ре-диез',
    'ми',
    'фа',
    'фа-диез',
    'соль',
    'соль-диез',
    'ля',
    'ля-диез',
    'си',
  ];

  static const flatNames = [
    'до',
    'ре-бемоль',
    'ре',
    'ми-бемоль',
    'ми',
    'фа',
    'соль-бемоль',
    'соль',
    'ля-бемоль',
    'ля',
    'си-бемоль',
    'си',
  ];

  static String fromMidi(int midi, {required bool useFlats}) {
    final pitchClass = midi % 12;
    return useFlats ? flatNames[pitchClass] : sharpNames[pitchClass];
  }

  static List<String> fromMidiList(
    List<int> midiNotes, {
    required bool useFlats,
  }) {
    return midiNotes.map((n) => fromMidi(n, useFlats: useFlats)).toList();
  }

  static int letterIndex(String noteName) {
    for (var i = 0; i < naturalNames.length; i++) {
      final naturalName = naturalNames[i];
      if (noteName == naturalName || noteName.startsWith('$naturalName-')) {
        return i;
      }
    }
    throw ArgumentError.value(noteName, 'noteName', 'Неизвестное имя ноты');
  }

  static String spellScaleDegree({
    required int midi,
    required String tonicName,
    required int degreeIndex,
  }) {
    final tonicLetter = letterIndex(tonicName);
    final letter = (tonicLetter + degreeIndex) % naturalNames.length;
    final naturalName = naturalNames[letter];
    final naturalPitchClass = naturalPitchClasses[letter];
    var accidental = (midi % 12) - naturalPitchClass;
    if (accidental > 6) accidental -= 12;
    if (accidental < -6) accidental += 12;

    return switch (accidental) {
      -2 => '$naturalName-дубль-бемоль',
      -1 => '$naturalName-бемоль',
      0 => naturalName,
      1 => '$naturalName-диез',
      2 => '$naturalName-дубль-диез',
      _ => throw StateError(
          'Не поддерживается альтерация $accidental для MIDI $midi',
        ),
    };
  }

  static List<String> spellScale({
    required String tonicName,
    required List<int> midiNotes,
  }) {
    return [
      for (var i = 0; i < midiNotes.length; i++)
        spellScaleDegree(
          midi: midiNotes[i],
          tonicName: tonicName,
          degreeIndex: i,
        ),
    ];
  }
}
