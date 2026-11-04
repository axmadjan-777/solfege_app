import 'dart:async';

import 'package:flutter/material.dart';

import '../../curriculum/data/curriculum_catalog.dart';
import '../../curriculum/models/lesson.dart';
import '../../practice/progress/attempt.dart';
import '../../practice/audio/practice_audio_player.dart';
import '../../practice/audio/synthetic_practice_audio_player.dart';
import '../../practice/progress/clock.dart';
import '../../practice/progress/progress_rules.dart';
import '../../practice/progress/progress_store.dart';
import '../level0/lesson_review.dart';

class LessonReviewScreen extends StatefulWidget {
  const LessonReviewScreen({
    super.key,
    required this.lesson,
    required this.catalog,
    required this.progress,
    required this.clock,
    this.player,
  });

  final Lesson lesson;
  final CurriculumCatalog catalog;
  final ProgressStore progress;
  final Clock clock;
  final PracticeAudioPlayer? player;

  @override
  State<LessonReviewScreen> createState() => _LessonReviewScreenState();
}

class _LessonReviewScreenState extends State<LessonReviewScreen> {
  late final PracticeAudioPlayer _player =
      widget.player ?? SyntheticPracticeAudioPlayer();
  bool _playing = false;
  bool _heard = false;
  String? _audioError;

  late final _questions = lessonReviewQuestions(widget.lesson);
  final _coldAnswers = <bool>[];
  int _index = 0;
  bool _cold = false;
  bool _coldComplete = false;
  String? _feedback;
  String? _coldSessionId;

  CompetencySnapshot get _snapshot =>
      widget.progress.snapshot(widget.lesson.primaryCompetency);

  int get _coldCount {
    final configured =
        (widget.lesson.raw['cold_review'] as Map)['check_items'] as int;
    final minimum = widget.catalog.config.masteryRules.delayedMinItems;
    return configured < minimum ? minimum : configured;
  }

  bool get _ready {
    final provisional = _snapshot.provisionalAt;
    return provisional != null &&
        !widget.clock.now().isBefore(provisional.add(minimumColdReviewDelay));
  }

  void _record(List<bool> answers, {required bool cold}) {
    widget.progress.recordSession(SessionDraft(
      competencyId: widget.lesson.primaryCompetency,
      sessionId: cold
          ? _coldSessionId!
          : '${widget.lesson.id}-practice-${widget.progress.book.attempts.length}',
      correct: answers,
      policy: widget.catalog.config.policy(widget.lesson.coldReviewPolicyId),
      tonality: 'C',
      coldReview: cold,
      errorTag: widget.lesson.id,
      itemSignature:
          '${widget.lesson.id}-${cold ? 'cold' : _questions[_index % _questions.length].soundId}',
    ));
  }

  @override
  void dispose() {
    unawaited(_releaseAudio());
    super.dispose();
  }

  Future<void> _releaseAudio() async {
    try {
      await _player.stop();
    } catch (_) {
      // The route has already closed; still release the underlying player.
    } finally {
      try {
        await _player.dispose();
      } catch (_) {
        // No grading or UI updates are allowed after this route is disposed.
      }
    }
  }

  Future<void> _listen() async {
    if (_playing || _feedback != null || _coldComplete) return;
    setState(() {
      _playing = true;
      _heard = false;
      _audioError = null;
    });
    try {
      await _player.play(_questions[_index % _questions.length].audio);
      if (mounted) setState(() => _heard = true);
    } catch (_) {
      if (mounted) {
        setState(() => _audioError =
            'Не удалось воспроизвести звук. Нажмите «Слушать» ещё раз.');
      }
    } finally {
      if (mounted) setState(() => _playing = false);
    }
  }

  void _answer(int answer) {
    if (!_heard || _playing || _feedback != null || _coldComplete) return;
    final correct = _questions[_index % _questions.length].correct(answer);
    if (_cold) {
      _coldAnswers.add(correct);
      if (_coldAnswers.length == _coldCount) {
        // Commit the whole check once: no answer-level feedback or progress
        // changes can reveal correctness during a delayed check.
        _record(List<bool>.of(_coldAnswers), cold: true);
        setState(() => _coldComplete = true);
      } else {
        setState(() {
          _index += 1;
          _heard = false;
        });
      }
      return;
    }
    _record([correct], cold: false);
    setState(() => _feedback =
        '${correct ? 'Верно' : 'Неверно'}. ${_questions[_index % _questions.length].explanation}');
  }

  void _startCold() {
    if (!_ready || _snapshot.status != CompetencyStatus.provisionallyPassed) {
      return;
    }
    setState(() {
      _cold = true;
      _heard = false;
      _index = 0;
      _feedback = null;
      _coldAnswers.clear();
      _coldSessionId =
          '${widget.lesson.id}-cold-${widget.clock.now().microsecondsSinceEpoch}-${widget.progress.book.attempts.length}';
    });
  }

  @override
  Widget build(BuildContext context) {
    final status = _snapshot.status;
    final waiting = !_cold && status == CompetencyStatus.provisionallyPassed;
    final mastered = status == CompetencyStatus.mastered;
    return Scaffold(
      appBar: AppBar(
          title: Text(_cold ? 'Холодная проверка' : 'Контрольная практика')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(widget.lesson.title,
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            if (mastered || _coldComplete) ...[
              Text(mastered ? 'Освоено' : 'Нужно повторить'),
              if (_coldComplete)
                Text(
                    'Верно ${_coldAnswers.where((answer) => answer).length} из ${_coldAnswers.length}'),
              if (!mastered)
                FilledButton(
                  onPressed: () => setState(() {
                    _cold = false;
                    _heard = false;
                    _coldComplete = false;
                    _index = 0;
                  }),
                  child: const Text('Повторить практику'),
                ),
            ] else if (waiting) ...[
              const Text('Предварительно сдано'),
              Text(_ready
                  ? 'Холодная проверка доступна'
                  : 'Холодная проверка доступна через 20 часов'),
              if (!_ready)
                TextButton(
                  onPressed: () => setState(() {}),
                  child: const Text('Проверить доступность'),
                ),
              Semantics(
                identifier: 'lesson-review-start-cold',
                child: FilledButton(
                  onPressed: _ready ? _startCold : null,
                  child: const Text('Начать холодную проверку'),
                ),
              ),
            ] else ...[
              if (_cold)
                Text('Задание ${_coldAnswers.length + 1} из $_coldCount'),
              const Text('Прослушайте сигнал. Можно ли его спеть?'),
              Semantics(
                identifier: 'lesson-review-play',
                child: FilledButton(
                  onPressed: _playing || _feedback != null ? null : _listen,
                  child: Text(_playing ? 'Слушаем…' : 'Слушать'),
                ),
              ),
              if (_audioError != null) Text(_audioError!),
              const SizedBox(height: 16),
              for (var answer = 0; answer < 2; answer++)
                Semantics(
                  identifier: 'lesson-review-answer-$answer',
                  child: FilledButton(
                    onPressed: _heard && !_playing && _feedback == null
                        ? () => _answer(answer)
                        : null,
                    child: Text(answer == 0 ? 'можно спеть' : 'нельзя спеть'),
                  ),
                ),
              if (_feedback != null) ...[
                Text(_feedback!),
                Semantics(
                  identifier: 'lesson-review-next',
                  child: FilledButton(
                    onPressed: () => setState(() {
                      _index += 1;
                      _heard = false;
                      _feedback = null;
                    }),
                    child: const Text('Следующее'),
                  ),
                ),
              ],
            ],
            const SizedBox(height: 16),
            TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('К теории')),
          ],
        ),
      ),
    );
  }
}
