import 'package:flutter_test/flutter_test.dart';
import 'package:solfege_app/features/scales/data/scales_repository.dart';

void main() {
  const repository = ScalesRepository();

  test('flat major scale keeps one written letter per degree', () {
    final eFlatMajor = repository.findScaleById('eb_c_major_natural')!;

    expect(
      eFlatMajor.notes,
      ['ми-бемоль', 'фа', 'соль', 'ля-бемоль', 'си-бемоль', 'до', 'ре'],
    );
  });

  test('harmonic major spells its lowered sixth as a flat', () {
    final cHarmonicMajor = repository.findScaleById('c_a_major_harmonic')!;

    expect(
      cHarmonicMajor.notes,
      ['до', 'ре', 'ми', 'фа', 'соль', 'ля-бемоль', 'си'],
    );
  });

  test('harmonic minor preserves degree letter for double accidental', () {
    final dSharpHarmonicMinor =
        repository.findScaleById('fs_ds_minor_harmonic')!;

    expect(
      dSharpHarmonicMinor.notes,
      [
        'ре-диез',
        'ми-диез',
        'фа-диез',
        'соль-диез',
        'ля-диез',
        'си',
        'до-дубль-диез',
      ],
    );
  });
}
