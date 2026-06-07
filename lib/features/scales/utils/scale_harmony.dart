import '../models/scale.dart';

class ScaleResolution {
  const ScaleResolution({
    required this.fromDegree,
    required this.toDegree,
    required this.fromNote,
    required this.toNote,
  });

  final String fromDegree;
  final String toDegree;
  final String fromNote;
  final String toNote;
}

class TriadInversion {
  const TriadInversion({
    required this.label,
    required this.notes,
  });

  final String label;
  final List<String> notes;
}

class ScaleHarmony {
  const ScaleHarmony._();

  static const unstableDegrees = {'II', 'IV', 'VI', 'VII'};

  static const resolutionMap = {
    'II': 'I',
    'IV': 'III',
    'VI': 'V',
    'VII': 'I',
  };

  static List<ScaleResolution> resolutionsFor(Scale scale) {
    final result = <ScaleResolution>[];
    for (var i = 0; i < Scale.degrees.length; i++) {
      final degree = Scale.degrees[i];
      if (!unstableDegrees.contains(degree)) continue;
      final target = resolutionMap[degree]!;
      final targetIndex = Scale.degrees.indexOf(target);
      result.add(
        ScaleResolution(
          fromDegree: degree,
          toDegree: target,
          fromNote: scale.notes[i],
          toNote: scale.notes[targetIndex],
        ),
      );
    }
    return result;
  }

  static List<String> triadNotes(Scale scale, int rootIndex) {
    return [
      scale.notes[rootIndex],
      scale.notes[(rootIndex + 2) % 7],
      scale.notes[(rootIndex + 4) % 7],
    ];
  }

  static List<int> triadMidis(Scale scale, int rootIndex) {
    return [
      scale.midiNotes[rootIndex],
      scale.midiNotes[(rootIndex + 2) % 7],
      scale.midiNotes[(rootIndex + 4) % 7],
    ];
  }

  static List<TriadInversion> triadInversions(Scale scale, int rootIndex) {
    final root = triadNotes(scale, rootIndex);
    return [
      TriadInversion(label: 'основной', notes: [root[0], root[1], root[2]]),
      TriadInversion(label: 'секстаккорд', notes: [root[1], root[2], root[0]]),
      TriadInversion(
        label: 'квартсекстаккорд',
        notes: [root[2], root[0], root[1]],
      ),
    ];
  }

  static int tonicIndex(Scale scale) => 0;

  static int subdominantIndex(Scale scale) =>
      scale.mode.isMajor ? 3 : 3;

  static int dominantIndex(Scale scale) => 4;
}
