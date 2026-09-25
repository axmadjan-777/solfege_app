enum ScaleModeFilter {
  all,
  major,
  minor;

  String get label {
    return switch (this) {
      ScaleModeFilter.all => 'Alle',
      ScaleModeFilter.major => 'Dur',
      ScaleModeFilter.minor => 'Moll',
    };
  }
}
