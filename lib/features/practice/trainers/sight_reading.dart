/// Фраза для чтения с листа. Скачок — от 3 полутонов, и только с I, III или V.
class SightPhrase {
  const SightPhrase(this.degrees);

  final List<int> degrees;

  static const scale = [0, 2, 4, 5, 7, 9, 11];
  static const stable = {1, 3, 5};

  bool get endsOnTonic => degrees.isNotEmpty && degrees.last == 1;

  bool get hasTritoneLeap {
    for (var i = 0; i < degrees.length - 1; i++) {
      if (_span(degrees[i], degrees[i + 1]) == 6) return true;
    }
    return false;
  }

  bool get leapsOnlyFromStable {
    for (var i = 0; i < degrees.length - 1; i++) {
      if (_span(degrees[i], degrees[i + 1]) >= 3 && !stable.contains(degrees[i])) return false;
    }
    return true;
  }

  int get chromaticCount => degrees.where((degree) => degree < 1 || degree > 7).length;

  bool get isAllowed => endsOnTonic && !hasTritoneLeap && leapsOnlyFromStable && chromaticCount <= 1;

  static int _span(int fromDegree, int toDegree) {
    if (fromDegree < 1 || fromDegree > 7 || toDegree < 1 || toDegree > 7) return 0;
    final jump = (scale[toDegree - 1] - scale[fromDegree - 1]).abs();
    return jump > 6 ? 12 - jump : jump;
  }
}

/// В MVP замок только у L03-10. Уроки L10-01…L10-03 не держат стадии 1–2.
bool pr13CanStart(bool Function(String competencyId) isMastered) {
  return isMastered('not.read_with_rhythm');
}

bool pr13StagePlayable(int stage) => stage == 1 || stage == 2;
