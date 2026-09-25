enum MusicianLevel {
  beginner,
  pro,
  expert;

  String get labelRu => switch (this) {
        MusicianLevel.beginner => 'Anfänger',
        MusicianLevel.pro => 'Fortgeschritten',
        MusicianLevel.expert => 'Experte',
      };

  String get descriptionRu => switch (this) {
        MusicianLevel.beginner =>
          'Ich fange gerade an oder habe lange nicht geübt',
        MusicianLevel.pro => 'Ich mache sicher Musik',
        MusicianLevel.expert =>
          'Ich unterrichte, studiere professionell oder bereite mich auf Prüfungen vor',
      };

  String get dbValue => name;

  static MusicianLevel fromDb(String value) => switch (value) {
        'beginner' => MusicianLevel.beginner,
        'pro' => MusicianLevel.pro,
        'expert' => MusicianLevel.expert,
        _ => MusicianLevel.beginner,
      };
}
