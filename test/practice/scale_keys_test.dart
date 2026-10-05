import 'package:solfege_app/features/practice/audio/audio_sequence.dart';
import 'package:solfege_app/features/practice/trainers/scale_keys.dart';
import 'package:test/test.dart';

void main() {
  test('sharps run by fifths from F, and G-sharp before C-sharp is rejected', () {
    expect(sharpOrder.join('-'), 'фа-до-соль-ре-ля-ми-си');
    expect(flatOrder, sharpOrder.reversed.toList());
    expect(signaturePrefix(sharps: true, count: 2), ['фа', 'до']);
    expect(signaturePrefix(sharps: true, count: 4), ['фа', 'до', 'соль', 'ре']);
    expect(gSharpBeforeCSharp(const ['соль', 'до']), isTrue);
    expect(sameOrder(const ['соль', 'до'], signaturePrefix(sharps: true, count: 2)), isFalse);
    expect(sameOrder(const ['фа', 'до'], signaturePrefix(sharps: true, count: 2)), isTrue);
    expect(majorFromSharpCount(1), 'соль');
    expect(majorFromSharpCount(2), 'ре');
    expect(majorFromSharpCount(4), 'ми');
    expect(majorFromFlatCount(1), 'фа');
    expect(majorFromFlatCount(2), 'си-бемоль');
    expect(majorFromFlatCount(4), 'ля-бемоль');
    expect(signaturePrefix(sharps: false, count: 2), ['си', 'ми']);
  });

  test('harmonic minor raises only VII, and melodic minor raises VI as well', () {
    expect(onlySeventhRaised(harmonicMinorSteps), isTrue);
    expect(sixthAndSeventhRaised(harmonicMinorSteps), isFalse);
    expect(sixthAndSeventhRaised(melodicAscendingSteps), isTrue);
    expect(matchesMinor(MinorForm.harmonic, melodicAscendingSteps), isFalse);
    expect(matchesMinor(MinorForm.harmonic, harmonicMinorSteps), isTrue);

    final harmonic = scaleMidi(60, harmonicMinorSteps);
    expect(harmonic[5], 68);
    expect(harmonic[6], 71);
    final melodic = scaleMidi(60, melodicAscendingSteps);
    expect(melodic[5], 69);
    expect(melodic[6], 71);

    final played = minorUpAndDown(60, MinorForm.melodic);
    final notes = played.events.whereType<NoteEvent>().map((event) => event.midi).toList();
    expect(notes.sublist(0, 8), [60, 62, 63, 65, 67, 69, 71, 72]);
    expect(notes.sublist(8), [70, 68, 67, 65, 63, 62, 60]);
    expect(notes.contains(71), isTrue);
    expect(notes.contains(70), isTrue);
  });

  test('a relative minor is a minor third down, and a parallel minor keeps the tonic', () {
    expect(relativeMinor('до'), 'ля');
    expect(relativeMinor('соль'), 'ми');
    expect(relativeMinor('фа'), 'ре');
    expect(relativeMinor('си-бемоль'), 'соль');
    expect(isRelativeMinor('до', 'ля'), isTrue);
    expect(isRelativeMinor('до', 'до'), isFalse);
    expect(isParallelMinor('до', 'до'), isTrue);
    expect(relativeMinorMidi(60), 57);
    expect(sameSignature('соль', 'ми'), isTrue);
    expect(sameSignature('до', 'до'), isFalse);
    expect(signatureCount('соль'), 1);
    expect(signatureCount('ми'), 4);
    expect(signatureCount('до'), 0);

    expect(fifthUp('до'), 'соль');
    expect(fifthUp('соль'), 'ре');
    expect(fifthDown('до'), 'фа');
    expect(fifthDown('фа'), 'си-бемоль');
    expect(mod12(syllablePitch(fifthUp('до')) - syllablePitch('до')), 7);
    expect(mod12(syllablePitch('до') - syllablePitch(fifthDown('до'))), 7);
    expect(signatureCount(fifthUp('ре')), signatureCount('ре') + 1);
    expect(signatureCount(fifthDown('ми-бемоль')), signatureCount('ми-бемоль') + 1);
  });

  test('stages 3–5 open only after their lessons, and twelve items need 0.85', () {
    expect(pr05LaterStageOpen(3, (id) => id == 'sca.key_signatures'), isTrue);
    expect(pr05LaterStageOpen(3, (id) => id == 'sca.major_formula'), isFalse);
    expect(
      pr05LaterStageOpen(
        4,
        (id) => id == 'sca.minor_natural' || id == 'sca.minor_harmonic' || id == 'sca.minor_melodic',
      ),
      isTrue,
    );
    expect(pr05LaterStageOpen(4, (id) => id == 'sca.minor_natural'), isFalse);
    expect(
      pr05LaterStageOpen(5, (id) => id == 'sca.relative_keys' || id == 'sca.circle_of_fifths'),
      isTrue,
    );
    expect(pr05LaterStageOpen(5, (id) => id == 'sca.relative_keys'), isFalse);
    expect(pr05LaterStageOpen(6, (_) => true), isFalse);
    expect(
      pr05LaterStageOpen(2, (id) => id == 'sca.major_formula' || id == 'sca.c_major' || id == 'sca.major_g_f'),
      isTrue,
    );
    expect(pr05LaterStageOpen(2, (id) => id == 'sca.key_signatures'), isFalse);
    expect(meetsStagePass(correct: 11, answered: 12), isTrue);
    expect(meetsStagePass(correct: 10, answered: 12), isFalse);
    expect(meetsStagePass(correct: 11, answered: 11), isFalse);
  });
}
