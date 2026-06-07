/// Russian solfege note naming for UI display.
abstract final class SolfegeNotes {
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
}
