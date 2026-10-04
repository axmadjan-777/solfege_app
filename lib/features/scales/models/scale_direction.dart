enum ScaleDirection {
  ascending,
  descending,
  upDown;

  String get labelRu {
    return switch (this) {
      ScaleDirection.ascending => 'aufwärts',
      ScaleDirection.descending => 'abwärts',
      ScaleDirection.upDown => 'auf- und abwärts',
    };
  }

  String get buttonLabel {
    return switch (this) {
      ScaleDirection.ascending => 'Aufwärts hören',
      ScaleDirection.descending => 'Abwärts hören',
      ScaleDirection.upDown => 'Auf- und abwärts hören',
    };
  }
}
