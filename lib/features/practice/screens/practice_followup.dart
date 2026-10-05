import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../curriculum/data/curriculum_catalog.dart';
import '../audio/practice_audio_player.dart';
import '../progress/clock.dart';
import '../progress/progress_store.dart';
import '../trainers/daily_mix.dart';
import '../trainers/harmony_and_melody.dart';
import '../trainers/interval_ear.dart';
import '../trainers/sight_reading.dart';
import '../trainers/v2_analysis.dart';
import 'chord_ear_screen.dart';
import 'daily_mix_screen.dart';
import 'degree_stage_screen.dart';
import 'dictation_stage_screen.dart';
import 'error_queue_screen.dart';
import 'interval_build_screen.dart';
import 'interval_choice_screen.dart';
import 'minor_degree_screen.dart';
import 'note_reading_screen.dart';
import 'rhythm_stage_screen.dart';
import 'scale_ear_screen.dart';
import 'sight_reading_screen.dart';
import 'triad_error_screen.dart';

/// Первый экран тренажёра, куда ведёт «Тренировать» и карта практики.
Widget practiceSetScreen({
  required String setId,
  required PracticeAudioPlayer player,
  required CurriculumCatalog catalog,
}) {
  return switch (setId) {
    'PR-01' => DegreeStageScreen(
        tonicMidi: 60, noteMidi: 60, player: player, onAnswered: (_) {}),
    'PR-02' => MinorDegreeScreen(
        tonicMidi: 69, noteMidi: 69, player: player, onAnswered: (_) {}),
    'PR-03' => IntervalChoiceScreen(
        bassMidi: 60,
        steps: IntervalEar.semitones['м3']!,
        labels: const ['м3', 'б3'],
        harmonic: false,
        player: player,
        onAnswered: (_) {},
      ),
    'PR-04' => IntervalBuildScreen(onFinished: (_) {}),
    'PR-05' => ScaleEarScreen(major: true, player: player, onAnswered: (_) {}),
    'PR-06' => ChordEarScreen(
        pitches: const [60, 64, 67], player: player, onAnswered: (_) {}),
    'PR-07' =>
      TriadErrorScreen(pitches: const [60, 65, 67], onAnswered: (_) {}),
    'PR-08' => NoteReadingScreen(midi: 60, unlocked: true, onAnswer: (_) {}),
    'PR-09' => RhythmStageScreen(unlocked: true, player: player, onHit: (_) {}),
    'PR-10' => DictationStageScreen(onFinished: (_) {}),
    'PR-11' => const MelodyFollowup(),
    'PR-12' => const CadenceFollowup(),
    'PR-13' => SightReadingScreen(
        phrase: const SightPhrase([1, 2, 3, 1]),
        player: player,
        onFinished: (_) {}),
    'PR-14' => const SingFollowup(),
    'PR-15' => DailyMixScreen(plan: _dailyMix()),
    'PR-16' => ErrorQueueScreen(
        store: MemoryProgressStore(
          clock: FixedClock(DateTime.utc(2026, 10, 5)),
          rules: catalog.config.masteryRules,
        ),
        onColdReview: (_) {},
      ),
    _ => _UnknownPractice(setId: setId),
  };
}

DailyMixPlan _dailyMix() {
  return buildDailyMix(
    seed: 1,
    count: 4,
    pool: [
      for (var i = 0; i < 6; i++)
        MixItem(id: 'due-$i', bucket: MixBucket.due, action: MixAction.aural),
      for (var i = 0; i < 3; i++)
        MixItem(
            id: 'recent-$i',
            bucket: MixBucket.recent,
            action: MixAction.active),
      for (var i = 0; i < 2; i++)
        MixItem(id: 'easy-$i', bucket: MixBucket.easy, action: MixAction.aural),
    ],
  );
}

class MelodyFollowup extends StatelessWidget {
  const MelodyFollowup({super.key});

  @override
  Widget build(BuildContext context) {
    final closed = tonicTriadMelody(const [1, 3, 5, 1]);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Мелодический диктант')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
            closed ? 'Фраза 1–3–5–1 кончается на тонике' : 'Фраза не закрыта'),
      ),
    );
  }
}

class CadenceFollowup extends StatelessWidget {
  const CadenceFollowup({super.key});

  @override
  Widget build(BuildContext context) {
    final authentic = cadenceType(const ['V', 'I']) == 'authentic';
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Каденция')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(authentic ? 'V–I — автентическая' : 'Каденция не узнана'),
      ),
    );
  }
}

class SingFollowup extends StatelessWidget {
  const SingFollowup({super.key});

  @override
  Widget build(BuildContext context) {
    final report = !singAttemptGrantsMastered();
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Пение')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(report
            ? '${singPrompt('tonic')}. Это самоотчёт'
            : 'Оценка включена'),
      ),
    );
  }
}

class _UnknownPractice extends StatelessWidget {
  const _UnknownPractice({required this.setId});

  final String setId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(setId)),
      body: const Padding(
        padding: EdgeInsets.all(24),
        child: Text('Для этого тренажёра ещё нет экрана'),
      ),
    );
  }
}
