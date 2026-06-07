enum ScaleModeFilter {
  all,
  major,
  minor;

  String get label {
    return switch (this) {
      ScaleModeFilter.all => 'Все',
      ScaleModeFilter.major => 'Мажор',
      ScaleModeFilter.minor => 'Минор',
    };
  }
}
