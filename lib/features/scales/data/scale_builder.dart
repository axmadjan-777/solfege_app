import '../models/key_signature_category.dart';
import '../models/key_signature_group.dart';
import '../models/scale.dart';
import '../models/scale_mode.dart';
import '../utils/solfege_notes.dart';

class ScaleBuilder {
  const ScaleBuilder();

  static const _majorNatural = [0, 2, 4, 5, 7, 9, 11];
  static const _majorHarmonic = [0, 2, 4, 5, 7, 8, 11];
  static const _minorNatural = [0, 2, 3, 5, 7, 8, 10];
  static const _minorHarmonic = [0, 2, 3, 5, 7, 8, 11];
  static const _minorMelodicUp = [0, 2, 3, 5, 7, 9, 11];

  static const _sharpSignLabels = [
  'фа-диез',
  'до-диез',
  'соль-диез',
  'ре-диез',
  'ля-диез',
  'ми-диез',
  'си-диез',
];

  static const _flatSignLabels = [
  'си-бемоль',
  'ми-бемоль',
  'ля-бемоль',
  'ре-бемоль',
  'соль-бемоль',
  'до-бемоль',
  'фа-бемоль',
];

  List<KeySignatureGroup> buildAllGroups() {
    return [
      _group(
        id: 'c_a',
        majorTonicMidi: 60,
        minorTonicMidi: 69,
        majorTonicName: 'до',
        minorTonicName: 'ля',
        category: KeySignatureCategory.none,
        signCount: 0,
        signLabels: const [],
      ),
      _group(
        id: 'g_e',
        majorTonicMidi: 67,
        minorTonicMidi: 64,
        majorTonicName: 'соль',
        minorTonicName: 'ми',
        category: KeySignatureCategory.sharps,
        signCount: 1,
        signLabels: _sharpSignLabels.sublist(0, 1),
      ),
      _group(
        id: 'd_b',
        majorTonicMidi: 62,
        minorTonicMidi: 71,
        majorTonicName: 'ре',
        minorTonicName: 'си',
        category: KeySignatureCategory.sharps,
        signCount: 2,
        signLabels: _sharpSignLabels.sublist(0, 2),
      ),
      _group(
        id: 'a_fs',
        majorTonicMidi: 69,
        minorTonicMidi: 66,
        majorTonicName: 'ля',
        minorTonicName: 'фа-диез',
        category: KeySignatureCategory.sharps,
        signCount: 3,
        signLabels: _sharpSignLabels.sublist(0, 3),
      ),
      _group(
        id: 'e_cs',
        majorTonicMidi: 64,
        minorTonicMidi: 73,
        majorTonicName: 'ми',
        minorTonicName: 'до-диез',
        category: KeySignatureCategory.sharps,
        signCount: 4,
        signLabels: _sharpSignLabels.sublist(0, 4),
      ),
      _group(
        id: 'b_gs',
        majorTonicMidi: 71,
        minorTonicMidi: 68,
        majorTonicName: 'си',
        minorTonicName: 'соль-диез',
        category: KeySignatureCategory.sharps,
        signCount: 5,
        signLabels: _sharpSignLabels.sublist(0, 5),
      ),
      _group(
        id: 'fs_ds',
        majorTonicMidi: 66,
        minorTonicMidi: 75,
        majorTonicName: 'фа-диез',
        minorTonicName: 'ре-диез',
        category: KeySignatureCategory.sharps,
        signCount: 6,
        signLabels: _sharpSignLabels.sublist(0, 6),
      ),
      _group(
        id: 'cs_as',
        majorTonicMidi: 61,
        minorTonicMidi: 70,
        majorTonicName: 'до-диез',
        minorTonicName: 'ля-диез',
        category: KeySignatureCategory.sharps,
        signCount: 7,
        signLabels: _sharpSignLabels,
      ),
      _group(
        id: 'f_d',
        majorTonicMidi: 65,
        minorTonicMidi: 62,
        majorTonicName: 'фа',
        minorTonicName: 'ре',
        category: KeySignatureCategory.flats,
        signCount: 1,
        signLabels: _flatSignLabels.sublist(0, 1),
      ),
      _group(
        id: 'bb_g',
        majorTonicMidi: 70,
        minorTonicMidi: 67,
        majorTonicName: 'си-бемоль',
        minorTonicName: 'соль',
        category: KeySignatureCategory.flats,
        signCount: 2,
        signLabels: _flatSignLabels.sublist(0, 2),
      ),
      _group(
        id: 'eb_c',
        majorTonicMidi: 63,
        minorTonicMidi: 60,
        majorTonicName: 'ми-бемоль',
        minorTonicName: 'до',
        category: KeySignatureCategory.flats,
        signCount: 3,
        signLabels: _flatSignLabels.sublist(0, 3),
      ),
      _group(
        id: 'ab_f',
        majorTonicMidi: 68,
        minorTonicMidi: 65,
        majorTonicName: 'ля-бемоль',
        minorTonicName: 'фа',
        category: KeySignatureCategory.flats,
        signCount: 4,
        signLabels: _flatSignLabels.sublist(0, 4),
      ),
      _group(
        id: 'db_bb',
        majorTonicMidi: 61,
        minorTonicMidi: 70,
        majorTonicName: 'ре-бемоль',
        minorTonicName: 'си-бемоль',
        category: KeySignatureCategory.flats,
        signCount: 5,
        signLabels: _flatSignLabels.sublist(0, 5),
      ),
      _group(
        id: 'gb_eb',
        majorTonicMidi: 66,
        minorTonicMidi: 63,
        majorTonicName: 'соль-бемоль',
        minorTonicName: 'ми-бемоль',
        category: KeySignatureCategory.flats,
        signCount: 6,
        signLabels: _flatSignLabels.sublist(0, 6),
      ),
      _group(
        id: 'cb_ab',
        majorTonicMidi: 59,
        minorTonicMidi: 68,
        majorTonicName: 'до-бемоль',
        minorTonicName: 'ля-бемоль',
        category: KeySignatureCategory.flats,
        signCount: 7,
        signLabels: _flatSignLabels,
      ),
    ];
  }

  KeySignatureGroup _group({
    required String id,
    required int majorTonicMidi,
    required int minorTonicMidi,
    required String majorTonicName,
    required String minorTonicName,
    required KeySignatureCategory category,
    required int signCount,
    required List<String> signLabels,
  }) {
    final useFlats = category == KeySignatureCategory.flats;
    final title = '$majorTonicName мажор / $minorTonicName минор';

    return KeySignatureGroup(
      id: id,
      title: title,
      category: category,
      signCount: signCount,
      signLabels: signLabels,
      scales: [
        _buildScale(
          id: '${id}_major_natural',
          tonicName: majorTonicName,
          tonicMidi: majorTonicMidi,
          mode: ScaleMode.major,
          intervals: _majorNatural,
          useFlats: useFlats,
          isMajor: true,
        ),
        _buildScale(
          id: '${id}_major_harmonic',
          tonicName: majorTonicName,
          tonicMidi: majorTonicMidi,
          mode: ScaleMode.harmonicMajor,
          intervals: _majorHarmonic,
          useFlats: useFlats,
          isMajor: true,
        ),
        _buildScale(
          id: '${id}_minor_natural',
          tonicName: minorTonicName,
          tonicMidi: minorTonicMidi,
          mode: ScaleMode.naturalMinor,
          intervals: _minorNatural,
          useFlats: useFlats,
          isMajor: false,
        ),
        _buildScale(
          id: '${id}_minor_harmonic',
          tonicName: minorTonicName,
          tonicMidi: minorTonicMidi,
          mode: ScaleMode.harmonicMinor,
          intervals: _minorHarmonic,
          useFlats: useFlats,
          isMajor: false,
        ),
        _buildScale(
          id: '${id}_minor_melodic',
          tonicName: minorTonicName,
          tonicMidi: minorTonicMidi,
          mode: ScaleMode.melodicMinor,
          intervals: _minorMelodicUp,
          useFlats: useFlats,
          isMajor: false,
          melodicMinor: true,
        ),
      ],
    );
  }

  Scale _buildScale({
    required String id,
    required String tonicName,
    required int tonicMidi,
    required ScaleMode mode,
    required List<int> intervals,
    required bool useFlats,
    required bool isMajor,
    bool melodicMinor = false,
  }) {
    final midiNotes = intervals.map((i) => tonicMidi + i).toList();
    final notes = SolfegeNotes.fromMidiList(midiNotes, useFlats: useFlats);

    List<String>? descendingNotes;
    List<int>? descendingMidiNotes;
    if (melodicMinor) {
      descendingMidiNotes = [tonicMidi];
      for (var stepIndex = _minorNatural.length - 1; stepIndex >= 1; stepIndex--) {
        var midi = tonicMidi + _minorNatural[stepIndex];
        while (midi > tonicMidi) {
          midi -= 12;
        }
        descendingMidiNotes.add(midi);
      }
      descendingNotes = SolfegeNotes.fromMidiList(
        descendingMidiNotes,
        useFlats: useFlats,
      );
    }

    final name = '$tonicName ${mode.fullLabelRu}';

    return Scale(
      id: id,
      name: name,
      tonic: tonicName,
      mode: mode,
      notes: notes,
      midiNotes: midiNotes,
      description: _description(
        tonicName: tonicName,
        mode: mode,
        isMajor: isMajor,
      ),
      listeningTips: _listeningTips(mode),
      descendingNotes: descendingNotes,
      descendingMidiNotes: descendingMidiNotes,
    );
  }

  String _description({
    required String tonicName,
    required ScaleMode mode,
    required bool isMajor,
  }) {
    return switch (mode) {
      ScaleMode.major =>
        '$tonicName мажор натуральный — классическая мажорная гамма с устойчивыми I, III и V ступенями.',
      ScaleMode.harmonicMajor =>
        '$tonicName мажор гармонический — мажор с пониженной VI ступенью. '
            'Реже встречается в учебных программах, но полезен для сравнения ладов.',
      ScaleMode.naturalMinor =>
        '$tonicName минор натуральный — базовый минорный лад без повышенных ступеней.',
      ScaleMode.harmonicMinor =>
        '$tonicName минор гармонический — минор с повышенной VII ступенью.',
      ScaleMode.melodicMinor =>
        '$tonicName минор мелодический — вверх с повышенными VI и VII, вниз натуральный минор.',
    };
  }

  List<String> _listeningTips(ScaleMode mode) {
    return switch (mode) {
      ScaleMode.major => const [
        'Обратите внимание на устойчивое звучание I, III и V ступеней.',
        'VII ступень тяготеет к тонике.',
      ],
      ScaleMode.harmonicMajor => const [
        'Обратите внимание на пониженную VI ступень по сравнению с натуральным мажором.',
        'Гамма звучит мягче и менее «классически мажорно».',
      ],
      ScaleMode.naturalMinor => const [
        'Сравните с параллельным мажором: общий состав звуков, другая тоника.',
        'VII ступень не создаёт сильного ведущего тона.',
      ],
      ScaleMode.harmonicMinor => const [
        'Обратите внимание на увеличенную секунду между VI и VII ступенями.',
        'VII ступень звучит как сильный вводный тон.',
      ],
      ScaleMode.melodicMinor => const [
        'При восхождении сравните с гармоническим минором.',
        'При спуске звучит как натуральный минор.',
      ],
    };
  }
}
