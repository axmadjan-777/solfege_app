enum Gender {
  male('male', 'Мужской'),
  female('female', 'Женский'),
  other('other', 'Другой'),
  preferNotSay('prefer_not_say', 'Не указывать');

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
