import '../../curriculum/models/lesson.dart';
import '../../practice/trainers/degree_dictation.dart';
import '../../practice/trainers/harmony_and_melody.dart';
import '../../practice/trainers/interval_direction.dart';
import '../../practice/trainers/interval_ear.dart';
import '../../practice/trainers/minor_degree_dictation.dart';
import '../../practice/trainers/modes_and_sevenths.dart';
import '../../practice/trainers/rhythm_advanced.dart';
import '../../practice/trainers/sight_reading.dart';
import '../../practice/trainers/triad_formulas.dart';
import '../../practice/trainers/triad_spelling.dart';
import '../../practice/trainers/v2_analysis.dart';
import '../../scales/utils/solfege_notes.dart';
import 'level0_plan.dart';

/// Два ответа карточки. Верный текст собирается из правил, а не из константы урока.
class LessonChoice {
  const LessonChoice(
      {required this.question, required this.right, required this.wrong});

  final String question;
  final String right;
  final String wrong;
}

class LessonScript {
  const LessonScript({required this.guided, this.transfer});

  final LessonChoice guided;
  final LessonChoice? transfer;
}

const lateTheoryLevels = {5, 7, 8, 9, 10, 11};

const _separatePlans = {'L05-01', 'L08-02', 'L10-05'};

/// Проходимые шаги уровней 5, 7–11. Уровень 6 и три ранних урока собраны отдельно.
List<Level0Step>? lateLevelSteps(Lesson lesson) {
  if (!lateTheoryLevels.contains(lesson.level) ||
      _separatePlans.contains(lesson.id)) {
    return null;
  }
  final script = lessonScript(lesson.id);
  final transfer = script.transfer ?? script.guided;
  return [
    Level0Step(
        kind: 'explanation', body: lesson.plainExplanation, templateId: 'text'),
    _choice(lesson, 'guided', script.guided.question, script.guided),
    _choice(
      lesson,
      'transfer',
      identical(transfer, script.guided) ? lesson.finalTask : transfer.question,
      transfer,
    ),
  ];
}

LessonScript lessonScript(String id) {
  return switch (id) {
    'L05-02' => _perfectIntervals(),
    'L05-03' => _seconds(),
    'L05-04' => _thirds(),
    'L05-05' => _sixthsAndSevenths(),
    'L05-06' => _unisonAndOctave(),
    'L05-07' => LessonScript(
        guided: LessonChoice(
          question: 'Большая терция вверх от до',
          right: _name(noteAbove(60, 'б3')),
          wrong: _name(noteAbove(60, 'м3')),
        ),
      ),
    'L05-08' => _downFromG(),
    'L05-09' => LessonScript(
        guided: LessonChoice(
          question: 'Обращение малой терции',
          right: inversionRule('м3') ? invertedLabel('м3') : 'ошибка',
          wrong: 'м6',
        ),
      ),
    'L05-10' => _melodicOrHarmonic(),
    'L05-11' => _tritone(),
    'L08-01' => _twoThirds(),
    'L08-03' => LessonScript(
        guided: LessonChoice(
          question: 'Формула малого трезвучия',
          right: TriadFormulas.classify(const [60, 63, 67]) == 'minor'
              ? _formula(TriadFormulas.minor)
              : 'ошибка',
          wrong: _formula(TriadFormulas.major),
        ),
      ),
    'L08-04' => _majorAgainstMinor(),
    'L08-05' => LessonScript(
        guided: LessonChoice(
          question: 'Формула уменьшённого трезвучия',
          right: TriadFormulas.classify(const [60, 63, 66]) == 'dim'
              ? _formula(TriadFormulas.diminished)
              : 'ошибка',
          wrong: _formula(TriadFormulas.minor),
        ),
      ),
    'L08-06' => LessonScript(
        guided: LessonChoice(
          question: 'Формула увеличенного трезвучия',
          right: TriadFormulas.classify(const [60, 64, 68]) == 'aug'
              ? _formula(TriadFormulas.augmented)
              : 'ошибка',
          wrong: _formula(TriadFormulas.major),
        ),
      ),
    'L08-07' => _fourTriadKinds(),
    'L08-08' => _firstInversionBass(),
    'L08-09' => _secondInversionBass(),
    'L08-10' => _degreesOfMajor(),
    'L08-11' => LessonScript(
        guided: LessonChoice(
          question: 'V ступень минора',
          right: harmonicMinorTriads[4] == 'major' &&
                  naturalMinorTriads[4] == 'minor'
              ? 'мажор в гармоническом'
              : 'ошибка',
          wrong: 'минор, как в натуральном',
        ),
      ),
    'L10-01' => LessonScript(
        guided: LessonChoice(
          question: 'Фраза 1–2–3–1',
          right: const SightPhrase([1, 2, 3, 1]).isAllowed
              ? 'можно читать'
              : 'ошибка',
          wrong: 'скачок с неустоя',
        ),
      ),
    'L10-02' => _readDegreeOne(),
    'L10-03' => _triadLeaps(),
    'L10-04' => LessonScript(
        guided: LessonChoice(
          question: 'Какую фразу можно удержать как эхо тонического трезвучия?',
          right: tonicTriadMelody(const [1, 3, 5, 1]) ? '1–3–5–1' : 'ошибка',
          wrong: '1–2–4–6',
        ),
      ),
    'L10-06' => LessonScript(
        guided: LessonChoice(
          question:
              'Куда должна прийти мелодия диктанта на ступенях I, III и V?',
          right: tonicTriadMelody(const [1, 5, 3, 1]) ? 'на тонику' : 'ошибка',
          wrong: 'на II',
        ),
      ),
    'L10-07' => _findTritone(),
    'L10-08' => LessonScript(
        guided: LessonChoice(
          question: 'Чем заканчивается пение без микрофона?',
          right: !singAttemptGrantsMastered() && !singGrantsMastered('спел')
              ? 'самоотчёт'
              : 'ошибка',
          wrong: 'mastered',
        ),
      ),
    'L07-01' => const LessonScript(
        guided: LessonChoice(
          question: 'Длительность шестнадцатой',
          right: sixteenth == 0.25 ? '1/4 четверти' : 'ошибка',
          wrong: '1/2 четверти',
        ),
      ),
    'L07-02' => LessonScript(
        guided: LessonChoice(
          question: 'Восьмая и две шестнадцатые вместе',
          right: _sameBeat(eighth + sixteenth + sixteenth, quarter)
              ? 'четверть'
              : 'ошибка',
          wrong: 'половинная',
        ),
      ),
    'L07-03' => LessonScript(
        guided: LessonChoice(
          question: 'Пунктирная восьмая и шестнадцатая',
          right: _sameBeat(dottedValue(eighth) + sixteenth, quarter)
              ? 'четверть'
              : 'ошибка',
          wrong: 'восьмая',
        ),
      ),
    'L07-04' => LessonScript(
        guided: LessonChoice(
          question: 'Акцент на слабой восьмой после пустой сильной',
          right: isSyncopated(const [false, true, false, false])
              ? 'синкопа'
              : 'ошибка',
          wrong: 'ровные доли',
        ),
      ),
    'L07-05' => LessonScript(
        guided: LessonChoice(
          question: 'Три триольные восьмые занимают',
          right: eighthTripletFillsOneQuarter() ? 'одна четверть' : 'ошибка',
          wrong: 'полторы четверти',
        ),
      ),
    'L07-06' => LessonScript(
        guided: LessonChoice(
          question: 'Сколько долей в размере 6/8?',
          right: beatGroups('6/8').length == 2 ? 'две доли' : 'ошибка',
          wrong: 'три доли',
        ),
      ),
    'L07-07' => _compoundVsSimple(),
    'L07-08' => LessonScript(
        guided: LessonChoice(
          question: 'Размер из пяти четвертей',
          right:
              beatGroups('5/4').fold<int>(0, (sum, group) => sum + group) == 5
                  ? '5/4'
                  : 'ошибка',
          wrong: '6/8',
        ),
      ),
    'L09-01' => LessonScript(
        guided: LessonChoice(
          question: 'Бас доминанты в до мажоре',
          right: _name(bassOf(romanTriad('V', tonic: 60))),
          wrong: _name(bassOf(romanTriad('IV', tonic: 60))),
        ),
      ),
    'L09-02' => _leadingTone(),
    'L09-03' => LessonScript(
        guided: LessonChoice(
          question: 'Каденция V–I',
          right: cadenceType(const ['V', 'I']) == 'authentic'
              ? 'автентическая'
              : 'ошибка',
          wrong: 'половинная',
        ),
      ),
    'L09-04' => LessonScript(
        guided: LessonChoice(
          question: 'Каденция V–vi',
          right: cadenceType(const ['V', 'vi']) == 'deceptive'
              ? 'прерванная'
              : 'ошибка',
          wrong: 'автентическая',
        ),
        transfer: LessonChoice(
          question: 'Каденция IV–I',
          right: cadenceType(const ['IV', 'I']) == 'plagal'
              ? 'плагальная'
              : 'ошибка',
          wrong: 'прерванная',
        ),
      ),
    'L09-05' => LessonScript(
        guided: LessonChoice(
          question: 'Последняя функция оборота I–V–vi–IV',
          right: const ['I', 'V', 'vi', 'IV'].last,
          wrong: 'I',
        ),
      ),
    'L09-06' => LessonScript(
        guided: LessonChoice(
          question: 'Каденция ii–V–I',
          right: cadenceType(const ['ii', 'V', 'I']) == 'authentic'
              ? 'автентическая'
              : 'ошибка',
          wrong: 'плагальная',
        ),
      ),
    'L09-07' => _harmonize(),
    'L09-08' => LessonScript(
        guided: LessonChoice(
          question: 'Бас функции V, с которого начинают разбор в до мажоре',
          right: _name(bassOf(romanTriad('V', tonic: 60))),
          wrong: _name(bassOf(romanTriad('I', tonic: 60))),
        ),
      ),
    'L11-01' => LessonScript(
        guided: LessonChoice(
          question: 'Сколько звуков в септаккорде?',
          right: seventhChords['dom7']!.length == 4 ? '4 звука' : 'ошибка',
          wrong: '3 звука',
        ),
      ),
    'L11-02' => LessonScript(
        guided: LessonChoice(
          question: 'Формула доминантсептаккорда',
          right: seventhBySteps(seventhChords['dom7']!) == 'dom7'
              ? _formula(seventhChords['dom7']!)
              : 'ошибка',
          wrong: '0–4–7',
        ),
      ),
    'L11-03' => _dominantInversion(),
    'L11-04' => LessonScript(
        guided: LessonChoice(
          question: 'Формула уменьшённого септаккорда',
          right: seventhBySteps(seventhChords['dim7']!) == 'dim7'
              ? _formula(seventhChords['dim7']!)
              : 'ошибка',
          wrong: _formula(seventhChords['m7b5']!),
        ),
      ),
    'L11-05' => _leadingSeventh(),
    'L11-06' => _dorian(),
    'L11-07' => _mixolydianDegree(),
    'L11-08' => LessonScript(
        guided: LessonChoice(
          question: 'Сколько звуков в мажорной пентатонике?',
          right: majorPentatonic.length == 5 ? '5 звуков' : 'ошибка',
          wrong: '7 звуков',
        ),
      ),
    'L11-09' => LessonScript(
        guided: LessonChoice(
          question: 'Шаг хроматической гаммы',
          right: chromaticStepwise(const [60, 61, 62]) ? 'полутон' : 'ошибка',
          wrong: 'тон',
        ),
      ),
    'L11-10' => LessonScript(
        guided: LessonChoice(
          question: 'Основной тон V/V в до мажоре',
          right: _name(tonicAFifthUp(tonicAFifthUp(60))),
          wrong: _name(tonicAFifthUp(60)),
        ),
      ),
    'L11-11' => LessonScript(
        guided: LessonChoice(
          question: 'До мажор заканчивается в соль мажоре',
          right: hasModulated(60, 67) ? 'модуляция' : 'ошибка',
          wrong: 'та же тоника',
        ),
      ),
    'L11-12' => _pivot(),
    'L11-13' => LessonScript(
        guided: LessonChoice(
          question: 'Фраза со ступенями 1–3–5–1',
          right: tonicTriadMelody(const [1, 3, 5, 1]) ? 'замкнута' : 'ошибка',
          wrong: 'разомкнута',
        ),
      ),
    _ => throw ArgumentError.value(id, 'id', 'Нет карточки позднего уровня'),
  };
}

LessonScript _compoundVsSimple() {
  final sameCount = eighthsInMeter('6/8') == eighthsInMeter('3/4');
  final different = beatGroups('6/8').join() != beatGroups('3/4').join();
  return LessonScript(
    guided: LessonChoice(
      question: 'Чем 6/8 отличается от 3/4?',
      right: sameCount && different ? 'разная группировка' : 'ошибка',
      wrong: 'разное число восьмых',
    ),
  );
}

LessonScript _leadingTone() {
  final leading = 60 + DegreeDictation.semitones[6];
  return LessonScript(
    guided: LessonChoice(
      question: 'Вводный тон до мажора',
      right: _name(leading),
      wrong: SolfegeNotes.fromMidi(leading - 1, useFlats: true),
    ),
  );
}

LessonScript _harmonize() {
  final tonic = romanTriad('I', tonic: 60);
  return LessonScript(
    guided: LessonChoice(
      question: 'Ми в тоническом трезвучии до мажора',
      right: noteBelongsToChord(64, tonic) ? 'входит' : 'ошибка',
      wrong: 'не входит',
    ),
    transfer: LessonChoice(
      question: 'Фа в тоническом трезвучии до мажора',
      right: noteBelongsToChord(65, tonic) ? 'ошибка' : 'не входит',
      wrong: 'входит',
    ),
  );
}

LessonScript _dominantInversion() {
  final tones = [for (final step in seventhChords['dom7']!) 60 + step];
  return LessonScript(
    guided: LessonChoice(
      question: 'Бас первого обращения V7 от до',
      right: _name(tones[1]),
      wrong: _name(tones.first),
    ),
  );
}

LessonScript _leadingSeventh() {
  const tonic = 69;
  const root = tonic + MinorDegreeDictation.raisedSeventh;
  final chord = [root, root + 3, root + 6, root + 9];
  final kind = seventhBySteps(relativeToBass(chord));
  return LessonScript(
    guided: LessonChoice(
      question: 'Вводный септаккорд гармонического ля минора',
      right: kind == 'dim7' ? 'dim7' : 'ошибка',
      wrong: 'dom7',
    ),
  );
}

LessonScript _dorian() {
  final dorian = modes['дорийский']!;
  final isDorian =
      dorian[2] == 3 && dorian[5] == 9 && modeBySteps(dorian) == 'дорийский';
  return LessonScript(
    guided: LessonChoice(
      question: 'Малая терция и большая секста',
      right: isDorian ? 'дорийский' : 'ошибка',
      wrong: 'эолийский',
    ),
  );
}

LessonScript _mixolydianDegree() {
  final ionian = modes['ионийский']!;
  final mixolydian = modes['миксолидийский']!;
  var changed = -1;
  for (var i = 0; i < ionian.length; i++) {
    if (ionian[i] != mixolydian[i]) changed = i;
  }
  return LessonScript(
    guided: LessonChoice(
      question: 'Ступень, которой миксолидийский отличается от ионийского',
      right: changed == 6 ? 'VII' : 'ошибка',
      wrong: 'III',
    ),
  );
}

LessonScript _pivot() {
  final inC = romanTriad('V', tonic: 60);
  final inG = romanTriad('I', tonic: 67);
  var same = inC.length == inG.length;
  for (var i = 0; same && i < inC.length; i++) {
    same = inC[i] == inG[i];
  }
  return LessonScript(
    guided: LessonChoice(
      question: 'Аккорд соль–си–ре принадлежит двум тональностям',
      right: same ? 'V в до и I в соль' : 'ошибка',
      wrong: 'только I в до',
    ),
  );
}

LessonScript _perfectIntervals() {
  return LessonScript(
    guided: LessonChoice(
      question: 'Сколько полутонов в чистой квинте?',
      right: '${IntervalEar.semitones['ч5']}',
      wrong: '${IntervalEar.semitones['ч4']}',
    ),
    transfer: LessonChoice(
      question: 'Сколько полутонов в чистой кварте?',
      right: '${IntervalEar.semitones['ч4']}',
      wrong: '${IntervalEar.semitones['ч5']}',
    ),
  );
}

LessonScript _seconds() {
  return LessonScript(
    guided: LessonChoice(
      question: 'Секунда в 2 полутона',
      right: IntervalEar.semitones['б2'] == 2 ? 'большая' : 'ошибка',
      wrong: 'малая',
    ),
    transfer: LessonChoice(
      question: 'Секунда в 1 полутон',
      right: IntervalEar.semitones['м2'] == 1 ? 'малая' : 'ошибка',
      wrong: 'большая',
    ),
  );
}

LessonScript _thirds() {
  return LessonScript(
    guided: LessonChoice(
      question: 'Терция в 4 полутона',
      right: IntervalEar.semitones['б3'] == 4 ? 'большая' : 'ошибка',
      wrong: 'малая',
    ),
    transfer: LessonChoice(
      question: 'Терция в 3 полутона',
      right: IntervalEar.semitones['м3'] == 3 ? 'малая' : 'ошибка',
      wrong: 'большая',
    ),
  );
}

LessonScript _sixthsAndSevenths() {
  return LessonScript(
    guided: LessonChoice(
      question: 'Большая секста, полутоны',
      right: '${IntervalEar.semitones['б6']}',
      wrong: '${IntervalEar.semitones['м6']}',
    ),
    transfer: LessonChoice(
      question: 'Малая септима, полутоны',
      right: '${IntervalEar.semitones['м7']}',
      wrong: '${IntervalEar.semitones['б7']}',
    ),
  );
}

LessonScript _unisonAndOctave() {
  return LessonScript(
    guided: const LessonChoice(
      question: 'Сколько полутонов в приме?',
      right: '0',
      wrong: '12',
    ),
    transfer: LessonChoice(
      question: 'Сколько полутонов в октаве?',
      right: IntervalEar.inversion(0) == 12 ? '12' : 'ошибка',
      wrong: '0',
    ),
  );
}

LessonScript _downFromG() {
  final fifth = noteBelow(67, 'ч5');
  final fourth = noteBelow(67, 'ч4');
  return LessonScript(
    guided: LessonChoice(
      question: 'Чистая квинта вниз от соль',
      right: !placedUpward(67, fifth) ? _name(fifth) : 'ошибка',
      wrong: _name(fourth),
    ),
  );
}

LessonScript _melodicOrHarmonic() {
  final together = intervalPlayback(
              bassMidi: 60, steps: IntervalEar.semitones['ч5']!, harmonic: true)
          .events
          .length ==
      1;
  final inSequence = intervalPlayback(
              bassMidi: 60,
              steps: IntervalEar.semitones['ч5']!,
              harmonic: false)
          .events
          .length ==
      2;
  return LessonScript(
    guided: LessonChoice(
      question: 'Гармонический интервал звучит',
      right: together && inSequence ? 'вместе' : 'ошибка',
      wrong: 'по очереди',
    ),
  );
}

LessonScript _tritone() {
  final steps = IntervalEar.semitones['тритон']!;
  return LessonScript(
    guided: LessonChoice(
      question: 'Сколько полутонов в тритоне?',
      right: steps == 6 ? '6' : 'ошибка',
      wrong: '7',
    ),
    transfer: LessonChoice(
      question: 'Обращение тритона',
      right: IntervalEar.labelFor(IntervalEar.inversion(steps)) == 'тритон'
          ? 'тритон'
          : 'ошибка',
      wrong: 'ч5',
    ),
  );
}

LessonScript _twoThirds() {
  final majorLower = TriadFormulas.major[1] - TriadFormulas.major[0];
  final majorUpper = TriadFormulas.major[2] - TriadFormulas.major[1];
  final minorLower = TriadFormulas.minor[1] - TriadFormulas.minor[0];
  final minorUpper = TriadFormulas.minor[2] - TriadFormulas.minor[1];
  return LessonScript(
    guided: LessonChoice(
      question: 'Две терции большого трезвучия снизу вверх',
      right: majorLower == 4 && majorUpper == 3
          ? 'большая, затем малая'
          : 'ошибка',
      wrong: 'малая, затем большая',
    ),
    transfer: LessonChoice(
      question: 'Две терции малого трезвучия снизу вверх',
      right: minorLower == 3 && minorUpper == 4
          ? 'малая, затем большая'
          : 'ошибка',
      wrong: 'большая, затем малая',
    ),
  );
}

LessonScript _majorAgainstMinor() {
  return LessonScript(
    guided: LessonChoice(
      question: 'Звуки 0–4–7',
      right: TriadFormulas.classify(const [60, 64, 67]) == 'major'
          ? 'большое'
          : 'ошибка',
      wrong: 'малое',
    ),
    transfer: LessonChoice(
      question: 'Звуки 0–3–7',
      right: TriadFormulas.classify(const [60, 63, 67]) == 'minor'
          ? 'малое'
          : 'ошибка',
      wrong: 'большое',
    ),
  );
}

LessonScript _fourTriadKinds() {
  final kinds = {
    TriadFormulas.classify(const [60, 64, 67]),
    TriadFormulas.classify(const [60, 63, 67]),
    TriadFormulas.classify(const [60, 63, 66]),
    TriadFormulas.classify(const [60, 64, 68]),
  };
  return LessonScript(
    guided: LessonChoice(
      question: 'Сколько разных видов в этих четырёх аккордах?',
      right: kinds.length == 4 && !kinds.contains(null) ? 'четыре' : 'ошибка',
      wrong: 'два',
    ),
  );
}

LessonScript _firstInversionBass() {
  final inversion = firstInversion(const [60, 64, 67]);
  final spelled = spellTriad(inversion);
  return LessonScript(
    guided: LessonChoice(
      question: 'Бас первого обращения до-мажорного трезвучия',
      right: spelled?.position == 'first' ? _name(inversion.first) : 'ошибка',
      wrong: 'до',
    ),
  );
}

LessonScript _secondInversionBass() {
  const chord = [67, 72, 76];
  final spelled = spellTriad(chord);
  return LessonScript(
    guided: LessonChoice(
      question: 'Бас второго обращения до-мажорного трезвучия',
      right: spelled?.position == 'second' && spelled?.quality == 'major'
          ? _name(chord.first)
          : 'ошибка',
      wrong: 'до',
    ),
  );
}

LessonScript _degreesOfMajor() {
  return LessonScript(
    guided: LessonChoice(
      question: 'Трезвучие II ступени до мажора',
      right:
          TriadFormulas.classify(triadOnDegree(tonic: 60, degree: 2)) == 'minor'
              ? 'минор'
              : 'ошибка',
      wrong: 'мажор',
    ),
    transfer: LessonChoice(
      question: 'Трезвучие V ступени до мажора',
      right:
          TriadFormulas.classify(triadOnDegree(tonic: 60, degree: 5)) == 'major'
              ? 'мажор'
              : 'ошибка',
      wrong: 'минор',
    ),
  );
}

LessonScript _readDegreeOne() {
  final midi = 60 + DegreeDictation.semitones[0];
  return LessonScript(
    guided: LessonChoice(
      question: 'I ступень до мажора',
      right:
          DegreeDictation.degreeNumber(60, midi) == 1 ? _name(midi) : 'ошибка',
      wrong: 'ре',
    ),
  );
}

LessonScript _triadLeaps() {
  return LessonScript(
    guided: LessonChoice(
      question: 'Ход I–V',
      right: triadLeap(1, 5) ? 'скачок по трезвучию' : 'ошибка',
      wrong: 'ход со II',
    ),
    transfer: LessonChoice(
      question: 'Ход II–VI',
      right: triadLeap(2, 6) ? 'ошибка' : 'не по трезвучию',
      wrong: 'скачок по трезвучию',
    ),
  );
}

LessonScript _findTritone() {
  return LessonScript(
    guided: LessonChoice(
      question: 'Фраза со ступенями 1–4–7–1',
      right:
          const SightPhrase([1, 4, 7, 1]).hasTritoneLeap ? 'тритон' : 'ошибка',
      wrong: 'всё верно',
    ),
    transfer: LessonChoice(
      question: 'Фраза со ступенями 1–3–5–1',
      right: const SightPhrase([1, 3, 5, 1]).isAllowed
          ? 'фраза годится'
          : 'ошибка',
      wrong: 'тритон',
    ),
  );
}

Level0Step _choice(
    Lesson lesson, String kind, String body, LessonChoice choice) {
  return Level0Step(
    kind: kind,
    body: body,
    templateId: 'T02',
    options: [choice.right, choice.wrong],
    correctIndex: 0,
    feedbackCorrect: lesson.feedbackCorrect,
    feedbackError: lesson.feedbackFirstError,
  );
}

String _formula(List<int> steps) => steps.join('–');

String _name(int midi) => SolfegeNotes.fromMidi(midi, useFlats: false);

bool _sameBeat(double actual, double expected) =>
    (actual - expected).abs() < 1e-9;
