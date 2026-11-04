import '../../curriculum/models/lesson.dart';
import '../../practice/audio/audio_sequence.dart';
import 'level0_plan.dart';

/// The first perception lesson has no PR set. Its existing category mapping
/// supplies separate control practice and delayed checks using synthesized
/// tones and noise, rather than recordings of the named instruments.
bool supportsLessonReview(Lesson lesson) => lesson.id == 'L00-01';

class LessonReviewQuestion {
  const LessonReviewQuestion(this.soundId, this.singable);

  final String soundId;
  final bool singable;

  AudioSequence get audio => AudioSequence([
        if (singable)
          NoteEvent(
              60 + (soundId.codeUnits.fold<int>(0, (a, b) => a + b) % 3) * 4,
              durationMs: 700)
        else
          NoiseEvent(soundId.codeUnits
              .fold<int>(17, (a, b) => (a * 31 + b) & 0x7fffffff)),
      ]);

  String get explanation => singable
      ? 'Это синтетический тон: у него есть ясная высота, его можно спеть.'
      : 'Это синтетический шум: одной ясной высоты нет, его нельзя спеть.';

  bool correct(int answer) => answer == (singable ? 0 : 1);
}

List<LessonReviewQuestion> lessonReviewQuestions(Lesson lesson) {
  if (!supportsLessonReview(lesson)) {
    throw ArgumentError('No control practice bank for ${lesson.id}');
  }
  final pool = (lesson.exerciseParams['sound_pool'] as List).cast<String>();
  return [
    for (final id in pool) LessonReviewQuestion(id, toneNoisePool[id]!.$2),
  ];
}
