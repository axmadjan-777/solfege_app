# Устройство приложения

Описывает реализованные модули и потоки данных. Это карта реализации;
проверки конкретного коммита и ограничения приёмки фиксируются в PR и CI,
а состав покрытия — в [testing.md](testing.md).

Запуск и проверки — в [README](../README.md), задачи и известные дефекты — в
[roadmap](product_roadmap.md), причины новых существенных решений — в
[decisions.md](decisions.md).

## Границы системы

Flutter-клиент показывает экраны, загружает встроенный учебный каталог,
считает локальный прогресс и синтезирует звук. Hosted Supabase отвечает за
авторизацию и профили. Серверная Edge Function из этого репозитория обращается
к Gemini. Браузерная версия публикуется на GitHub Pages; команды публикации
и её проверки описаны в README.

## Запуск и пять вкладок

[main.dart](../lib/main.dart) инициализирует Supabase и запускает
[SolfegeApp](../lib/app.dart). Его начальный экран —
[AuthGate](../lib/features/auth/screens/auth_gate.dart): он выбирает экран
настройки, входа, подтверждения email, восстановления пароля или заполнения
профиля. После готовности сессии и профиля открывается
[MainShellScreen](../lib/features/app/main_shell_screen.dart).

Проще говоря, сначала приложение проверяет, кто вошёл и завершена ли регистрация,
потом показывает основное меню.

Клиент настроен на implicit flow. Обработка email-ссылок и восстановления
пароля находится в AuthService/AuthGate; `token_hash` обрабатывается отдельным
путём. Активное восстановление удерживает экран нового пароля при событиях
входа, обновления токена и завершении уже начатого чтения профиля; после смены
пароля или выхода блокировка снимается. Наличие этого кода не подтверждает
доставку письма или настройку redirect.

| Вкладка | Что видит пользователь | Вход в код |
|---|---|---|
| Гаммы | Тональности, ноты и проигрывание гаммы | [ScalesListScreen](../lib/features/scales/screens/scales_list_screen.dart) |
| Теория | Карту уроков и объяснения с заданиями | [TheoryHomeScreen](../lib/features/theory/screens/theory_home_screen.dart) |
| Практика | Тренажёры и учебные сессии | [PracticeMapScreen](../lib/features/practice/screens/practice_map_screen.dart) |
| ИИ | Чат с музыкальным помощником | [AiChatScreen](../lib/features/ai/screens/ai_chat_screen.dart) |
| Профиль | Данные вошедшего пользователя | [ProfileScreen](../lib/features/profile/screens/profile_screen.dart) |

При первом входе [CoachController](../lib/features/coach/coach_controller.dart)
и [CoachOverlay](../lib/features/coach/coach_layer.dart) показывают восемь шагов
по теории, первому уроку и карте практики. Пропуск или завершение сохраняется
на устройстве в SharedPreferences (`coach_route_v1`); это состояние подсказок,
а не учебный прогресс.

Общие виджеты заданий находятся в [interaction](../lib/features/interaction/).
Оболочка загружает книгу текущего UUID, слушает её изменения и передаёт
`isMastered` в теорию и практику. `AuthGate` создаёт оболочку с ключом пользователя:
при смене аккаунта прежнее хранилище освобождается, поздняя загрузка A не
заменяет книгу B. Доступ к другим стадиям остаётся предметом APP-04 roadmap.

## Откуда берутся уроки и упражнения

[CurriculumAssetSource](../lib/features/curriculum/data/curriculum_asset_source.dart)
читает шесть файлов из [assets/curriculum](../assets/curriculum/) через
`rootBundle`, затем собирает
[CurriculumCatalog](../lib/features/curriculum/data/curriculum_catalog.dart).
Каталог содержит содержание, связи, параметры стадий и правила прогресса;
исполняемая логика тренажёров находится в [practice](../lib/features/practice/).

Уроки поставляются вместе с приложением. Сервер не присылает их при каждом
открытии. Как менять и проверять эти данные — в
[curriculum/README](curriculum/README.md); методические требования — в спецификации.

## Где сохраняются данные

| Данные | Реализованное хранение | Код |
|---|---|---|
| Вход и сессия | Supabase Auth; состояние сессии обслуживает SDK | [SupabaseClientProvider](../lib/core/supabase/supabase_client_provider.dart), [AuthService](../lib/features/auth/services/auth_service.dart) |
| Профиль | `public.profiles` в Supabase; чтение и upsert текущего пользователя | [ProfileService](../lib/features/auth/services/profile_service.dart) |
| Незавершённая регистрация | Metadata пользователя и временное локальное состояние | [auth/services](../lib/features/auth/services/) |
| Учебный прогресс | SharedPreferences, ключ `practice_progress_v1:<UUID>`, проверка владельца книги | [PracticeProgressBinding](../lib/features/practice/progress/practice_progress_binding.dart), [ProgressStore](../lib/features/practice/progress/progress_store.dart) |
| История чата | Список сообщений в памяти экрана | [AiChatScreen](../lib/features/ai/screens/ai_chat_screen.dart) |

Профиль сохраняется в облаке, учебный прогресс — на устройстве с разделением
по аккаунтам. Legacy-книга из общего ключа копируется только при точном
совпадении записанного владельца с текущим UUID и отсутствии новой книги.
Неизвестная/`local` книга не присваивается вошедшему пользователю и сохраняется
в прежнем ключе. Повреждённая собственная книга сообщает ошибку загрузки;
чужая книга не выдаётся. Облачная синхронизация не реализована.

[schema.sql](../supabase/schema.sql) описывает профиль и RLS. Содержимое файла
не подтверждает, что та же схема применена в живом проекте.

## Завершение первого урока и повтор

`Level0LessonPlayer` записывает результат при переходе на summary один раз;
CTA выполняет отдельный переход и не дублирует запись. У L00-01 нет связанного
PR-набора: [LessonReviewScreen](../lib/features/theory/screens/lesson_review_screen.dart)
даёт контрольную практику, затем отдельный cold из четырёх ответов не раньше
20 часов после provisional. В cold нет подсказок и промежуточной оценки;
сессия сохраняется целиком после последнего ответа. Пороги освоения прежние.
Карта теории показывает доступ к контролю/повтору после перезапуска.

Контроль и cold используют синтезированные тон и шум. Ответ разрешён только
после успешного завершения воспроизведения; выход останавливает плеер.
Основной текстовый план урока не заменён библиотекой инструментальных записей.
Точная граница методики — в [карточке L00-01](curriculum/spec.md#l00-01-музыкальный-тон-и-шум).

Ежедневный микс включает посещённые уроки без отдельного исполняемого тренажёра
по их собственному прогрессу. Наличие общей компетенции или scheduled metadata
не добавляет незнакомый урок. Отдельный тренажёр подавляет дублирующий lesson
fallback; сроки возврата сохраняются. Статус обычной практики находится в
отдельной нижней области и не перекрывает заголовок/задание.

## Как запускается звук гаммы

Кнопка на [ScaleDetailScreen](../lib/features/scales/screens/scale_detail_screen.dart)
вызывает [ScalePlayback](../lib/features/scales/logic/scale_playback.dart).
Он передаёт гамму и направление в
[ScaleToneAudioService](../lib/features/scales/services/scale_tone_audio_service.dart).
Сервис получает последовательность MIDI-нот, а
[ToneGenerator](../lib/features/scales/services/tone_generator.dart) превращает
каждую ноту в WAV в памяти. `audioplayers` проигрывает их последовательно.

Проще говоря, приложение само создаёт звук; для гамм не скачиваются аудиофайлы.
Слышимость и поведение плеера на устройствах проверяются отдельно от unit-тестов.

## Как сообщение доходит до Gemini

1. [AiChatScreen](../lib/features/ai/screens/ai_chat_screen.dart) передаёт историю в
   [GeminiAiChatService](../lib/features/ai/services/ai_chat_service.dart).
2. Сервис проверяет наличие сессии, оставляет последние 12 сообщений и вызывает
   Supabase Function `gemini-chat` с токеном пользователя.
3. [Edge Function](../supabase/functions/gemini-chat/index.ts) проверяет токен
   через Supabase Auth, проверяет сообщения и добавляет
   [серверную инструкцию](../supabase/functions/gemini-chat/master_prompt.ts).
4. Функция обращается к Gemini с серверным ключом и возвращает `answer`.
   Клиент добавляет ответ в список сообщений или показывает ошибку.

Пузыри сообщений сохраняют выделяемый текст и явно передают его в Semantics:
содержимое доступно проверке интерфейса и вспомогательным технологиям вместо
пустого read-only поля. Это не заменяет смысловую оценку ответа модели.

Телефон или браузер общается с серверным посредником. Ключ Gemini остаётся на
сервере. Настройка модели и функции описана в README; доступность реального API
офлайн-тестами не подтверждается.
