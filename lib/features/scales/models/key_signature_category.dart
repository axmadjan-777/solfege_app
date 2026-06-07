enum KeySignatureCategory {
  none,
  sharps,
  flats;

  String get labelRu => switch (this) {
        KeySignatureCategory.none => 'Без знаков',
        KeySignatureCategory.sharps => 'Диезные',
        KeySignatureCategory.flats => 'Бемольные',
      };
}

enum KeySignatureFilter {
  all,
  none,
  sharps,
  flats;

  String get labelRu => switch (this) {
        KeySignatureFilter.all => 'Все',
        KeySignatureFilter.none => 'Без знаков',
        KeySignatureFilter.sharps => 'Диезные',
        KeySignatureFilter.flats => 'Бемольные',
      };
}
