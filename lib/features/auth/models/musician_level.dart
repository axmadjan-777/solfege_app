enum MusicianLevel {
  beginner,
  pro,
  expert;

  String get labelRu => switch (this) {
        MusicianLevel.beginner => 'Новичок',
        MusicianLevel.pro => 'Профи',
        MusicianLevel.expert => 'Эксперт',
      };

  String get descriptionRu => switch (this) {
        MusicianLevel.beginner =>
          'Я только начинаю или давно не занимался',
        MusicianLevel.pro => 'Я уверенно занимаюсь музыкой',
        MusicianLevel.expert =>
          'Я преподаю, учусь профессионально или готовлюсь к экзаменам',
      };

  String get dbValue => name;

  static MusicianLevel fromDb(String value) => switch (value) {
        'beginner' => MusicianLevel.beginner,
        'pro' => MusicianLevel.pro,
        'expert' => MusicianLevel.expert,
        _ => MusicianLevel.beginner,
      };
}
