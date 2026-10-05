/// Восемь первых действий. Подсветка ведёт по теории, уроку и карте практики.
class CoachStep {
  const CoachStep({
    required this.title,
    required this.body,
    this.targetId,
    this.action,
    this.primary = 'Дальше',
    this.showTab,
    this.popOnAdvance = false,
  });

  final String title;
  final String body;
  final String? targetId;
  final String? action;
  final String primary;
  final int? showTab;
  final bool popOnAdvance;

  bool get waitsForAction => action != null;
}

const coachSteps = <CoachStep>[
  CoachStep(
    title: 'Короткий маршрут',
    body: 'Восемь шагов. Сначала теория, потом карта практики. Пропустить можно сразу.',
    primary: 'Поехали',
  ),
  CoachStep(
    title: 'Открой теорию',
    body: 'Уроки идут сверху вниз. Закрытый урок ждёт предыдущий.',
    targetId: 'nav-theory',
    action: 'open-theory',
  ),
  CoachStep(
    title: 'Первый урок',
    body: '«Музыкальный тон и шум» уже открыт. Нажми карточку.',
    targetId: 'lesson-first',
    action: 'open-lesson',
  ),
  CoachStep(
    title: 'Прочитай и иди дальше',
    body: 'Это объяснение. Кнопка «Дальше» откроет задание.',
    targetId: 'lesson-next',
    action: 'read-on',
  ),
  CoachStep(
    title: 'Выбери ответ',
    body: 'Две кнопки: можно спеть или нет. Подсветка не называет верный.',
    targetId: 'lesson-answer',
    action: 'answer',
  ),
  CoachStep(
    title: 'Закрепи шаг',
    body: 'Посмотри ответ и нажми «Дальше». Дальше в уроке те же кнопки.',
    targetId: 'lesson-next',
    action: 'confirm',
  ),
  CoachStep(
    title: 'Теперь практика',
    body: 'Тренажёр с подписью «Закрыто» ждёт сданный урок. «Скоро» — следующая версия.',
    primary: 'К практике',
    popOnAdvance: true,
  ),
  CoachStep(
    title: 'Карта практики',
    body: 'Закрыто — урок ещё не сдан. Скоро — следующая версия. Профиль, последняя вкладка, хранит имя и выход.',
    targetId: 'practice-heading',
    showTab: 2,
    primary: 'Понятно',
  ),
];

String? coachActionForTab(int index) {
  return switch (index) {
    1 => 'open-theory',
    _ => null,
  };
}
