/// Версия продукта, в которой появляется элемент контента.
enum MvpStatus {
  mvp('mvp', 'MVP'),
  v1_1('v1.1', 'v1.1'),
  v1_2('v1.2', 'v1.2'),
  v2('v2', 'v2');

  const MvpStatus(this.id, this.label);

  final String id;
  final String label;

  bool get isMvp => this == MvpStatus.mvp;

  static MvpStatus parse(String value) {
    return MvpStatus.values.firstWhere(
      (s) => s.id == value,
      orElse: () => throw ArgumentError.value(value, 'mvp_status'),
    );
  }
}

/// Ссылка на предпосылку: урок (`L04-11`) или компетенция (`C:sca.tonic`).
class PrerequisiteRef {
  const PrerequisiteRef._(this.raw, this.lessonId, this.competencyId);

  factory PrerequisiteRef.parse(String raw) {
    if (raw.startsWith('C:')) return PrerequisiteRef._(raw, null, raw.substring(2));
    return PrerequisiteRef._(raw, raw, null);
  }

  final String raw;
  final String? lessonId;
  final String? competencyId;

  bool get isLesson => lessonId != null;

  @override
  String toString() => raw;
}
