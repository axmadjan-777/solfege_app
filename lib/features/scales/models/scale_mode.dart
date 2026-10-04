enum ScaleMode {
  major,
  harmonicMajor,
  naturalMinor,
  harmonicMinor,
  melodicMinor;

  String get badgeLabel {
    return switch (this) {
      ScaleMode.major => 'Dur',
      ScaleMode.harmonicMajor => 'Harm. Dur',
      ScaleMode.naturalMinor => 'Nat. Moll',
      ScaleMode.harmonicMinor => 'Harm. Moll',
      ScaleMode.melodicMinor => 'Mel. Moll',
    };
  }

  String get fullLabelRu {
    return switch (this) {
      ScaleMode.major => 'Natürliches Dur',
      ScaleMode.harmonicMajor => 'Harmonisches Dur',
      ScaleMode.naturalMinor => 'Natürliches Moll',
      ScaleMode.harmonicMinor => 'Harmonisches Moll',
      ScaleMode.melodicMinor => 'Melodisches Moll',
    };
  }

  String get typeLabelRu {
    return switch (this) {
      ScaleMode.major => 'Dur',
      ScaleMode.harmonicMajor => 'Dur harm.',
      ScaleMode.naturalMinor => 'Moll nat.',
      ScaleMode.harmonicMinor => 'Moll harm.',
      ScaleMode.melodicMinor => 'Moll mel.',
    };
  }

  String get educationalHintRu {
    return switch (this) {
      ScaleMode.major =>
        'Klassisches Dur ohne veränderte Stufen.',
      ScaleMode.harmonicMajor =>
        'Harmonisches Dur: erniedrigte VI. Stufe.',
      ScaleMode.naturalMinor =>
        'Natürliches Moll: ohne erhöhte Stufen.',
      ScaleMode.harmonicMinor =>
        'Harmonisches Moll: erhöhte VII. Stufe.',
      ScaleMode.melodicMinor =>
        'Melodisches Moll: aufwärts sind VI und VII erhöht, abwärts klingt natürliches Moll.',
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
