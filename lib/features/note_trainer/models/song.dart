enum SongDifficulty {
  easy('easy', 'Легко'),
  medium('medium', 'Средне'),
  hard('hard', 'Сложно');

  const SongDifficulty(this.id, this.label);

  final String id;
  final String label;

  static SongDifficulty parse(String value) {
    return SongDifficulty.values.firstWhere(
      (item) => item.id == value,
      orElse: () => SongDifficulty.medium,
    );
  }
}

class PlayableSong {
  const PlayableSong({
    required this.id,
    required this.title,
    required this.artist,
    required this.difficulty,
    required this.expectedNotes,
    required this.notePositions,
    this.isCompleted = false,
    this.score = 0,
  });

  final String id;
  final String title;
  final String artist;
  final SongDifficulty difficulty;
  final List<String> expectedNotes;
  final List<int> notePositions;
  final bool isCompleted;
  final int score;

  PlayableSong copyWith({bool? isCompleted, int? score}) {
    return PlayableSong(
      id: id,
      title: title,
      artist: artist,
      difficulty: difficulty,
      expectedNotes: expectedNotes,
      notePositions: notePositions,
      isCompleted: isCompleted ?? this.isCompleted,
      score: score ?? this.score,
    );
  }
}
