enum KeySignatureCategory {
  none,
  sharps,
  flats;

  String get labelRu => switch (this) {
        KeySignatureCategory.none => 'Ohne Vorzeichen',
        KeySignatureCategory.sharps => 'Kreuze',
        KeySignatureCategory.flats => 'Bes',
      };
}

enum KeySignatureFilter {
  all,
  none,
  sharps,
  flats;

  String get labelRu => switch (this) {
        KeySignatureFilter.all => 'Alle',
        KeySignatureFilter.none => 'Ohne',
        KeySignatureFilter.sharps => 'Kreuze',
        KeySignatureFilter.flats => 'Bes',
      };
}
