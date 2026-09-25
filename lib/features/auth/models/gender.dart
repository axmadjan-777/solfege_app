enum Gender {
  male('male', 'Männlich'),
  female('female', 'Weiblich'),
  other('other', 'Divers'),
  preferNotSay('prefer_not_say', 'Keine Angabe');

  const Gender(this.dbValue, this.labelRu);

  final String dbValue;
  final String labelRu;

  static Gender? fromDb(String? value) {
    if (value == null) return null;
    for (final item in Gender.values) {
      if (item.dbValue == value) return item;
    }
    return null;
  }
}
