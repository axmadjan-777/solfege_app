enum ScaleMode {
  major,
  harmonicMajor,
  naturalMinor,
  harmonicMinor,
  melodicMinor;

  String get badgeLabel {
    return switch (this) {
      ScaleMode.major => 'Мажор',
      ScaleMode.harmonicMajor => 'Гарм. мажор',
      ScaleMode.naturalMinor => 'Нат. минор',
      ScaleMode.harmonicMinor => 'Гарм. минор',
      ScaleMode.melodicMinor => 'Мел. минор',
    };
  }

  String get fullLabelRu {
    return switch (this) {
      ScaleMode.major => 'Мажор натуральный',
      ScaleMode.harmonicMajor => 'Мажор гармонический',
      ScaleMode.naturalMinor => 'Минор натуральный',
      ScaleMode.harmonicMinor => 'Минор гармонический',
      ScaleMode.melodicMinor => 'Минор мелодический',
    };
  }

  String get typeLabelRu {
    return switch (this) {
      ScaleMode.major => 'Мажор',
      ScaleMode.harmonicMajor => 'Мажор гарм.',
      ScaleMode.naturalMinor => 'Минор нат.',
      ScaleMode.harmonicMinor => 'Минор гарм.',
      ScaleMode.melodicMinor => 'Минор мел.',
    };
  }

  String get educationalHintRu {
    return switch (this) {
      ScaleMode.major => 'Классический мажорный лад без изменённых ступеней.',
      ScaleMode.harmonicMajor => 'Мажор гармонический: пониженная VI ступень.',
      ScaleMode.naturalMinor => 'Минор натуральный: без повышенных ступеней.',
      ScaleMode.harmonicMinor =>
        'Минор гармонический: повышенная VII ступень.',
      ScaleMode.melodicMinor =>
        'Минор мелодический: вверх повышаются VI и VII, вниз — натуральный минор.',
    };
  }

  bool get isMajor =>
      this == ScaleMode.major || this == ScaleMode.harmonicMajor;

  bool get isMinor => !isMajor;

  /// Ступени, которые стоит визуально выделить на экране деталей.
  Set<String> get highlightedDegrees {
    return switch (this) {
      ScaleMode.major => {'I', 'III', 'V', 'VII'},
      ScaleMode.harmonicMajor => {'I', 'III', 'V', 'VI'},
      ScaleMode.naturalMinor => {'I', 'III', 'V'},
      ScaleMode.harmonicMinor => {'I', 'III', 'V', 'VII'},
      ScaleMode.melodicMinor => {'I', 'III', 'V', 'VI', 'VII'},
    };
  }
}
