enum ScaleDirection {
  ascending,
  descending,
  upDown;

  String get labelRu {
    return switch (this) {
      ScaleDirection.ascending => 'вверх',
      ScaleDirection.descending => 'вниз',
      ScaleDirection.upDown => 'вверх-вниз',
    };
  }

  String get buttonLabel {
    return switch (this) {
      ScaleDirection.ascending => 'Слушать вверх',
      ScaleDirection.descending => 'Слушать вниз',
      ScaleDirection.upDown => 'Слушать вверх-вниз',
    };
  }
}
