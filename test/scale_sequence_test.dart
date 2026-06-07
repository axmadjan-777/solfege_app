import 'package:flutter_test/flutter_test.dart';
import 'package:solfege_app/features/scales/models/scale.dart';
import 'package:solfege_app/features/scales/models/scale_direction.dart';
import 'package:solfege_app/features/scales/models/scale_mode.dart';

void main() {
  const cMajor = Scale(
    id: 'c_major',
    name: 'до мажор',
    tonic: 'до',
    mode: ScaleMode.major,
    notes: ['до', 'ре', 'ми', 'фа', 'соль', 'ля', 'си'],
    midiNotes: [60, 62, 64, 65, 67, 69, 71],
    description: 'test',
    listeningTips: ['tip'],
  );

  const melodicMinor = Scale(
    id: 'a_melodic',
    name: 'ля минор мелодический',
    tonic: 'ля',
    mode: ScaleMode.melodicMinor,
    notes: ['ля', 'си', 'до', 'ре', 'ми', 'фа-диез', 'соль-диез'],
    midiNotes: [69, 71, 72, 74, 76, 78, 80],
    descendingNotes: ['ля', 'соль', 'фа', 'ми', 'ре', 'до', 'си'],
    descendingMidiNotes: [69, 67, 65, 64, 62, 60, 59],
    description: 'test',
    listeningTips: ['tip'],
  );

  test('ascending plays 8 notes ending with octave tonic', () {
    expect(cMajor.midiSequence(ScaleDirection.ascending).length, 8);
    expect(cMajor.midiSequence(ScaleDirection.ascending).last, 72);
    expect(cMajor.noteSequence(ScaleDirection.ascending).last, 'до');
  });

  test('descending plays 8 notes starting from high tonic', () {
    final midi = cMajor.midiSequence(ScaleDirection.descending);
    expect(midi.length, 8);
    expect(midi.first, 72);
    expect(midi.last, 60);
  });

  test('melodic minor descending uses natural minor body', () {
    expect(
      melodicMinor.noteSequence(ScaleDirection.descending).first,
      'ля',
    );
    expect(melodicMinor.midiSequence(ScaleDirection.descending).first, 81);
  });

  test('upDown plays ascending then descending', () {
    final sequence = melodicMinor.midiSequence(ScaleDirection.upDown);
    expect(sequence.take(8).toList(), melodicMinor.midiSequence(ScaleDirection.ascending));
    expect(
      sequence.skip(8).toList(),
      melodicMinor.midiSequence(ScaleDirection.descending).skip(1).toList(),
    );
  });
}
