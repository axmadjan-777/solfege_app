# Устройство приложения

Описывает реализованные модули и потоки данных. Код приложения сверен 2026-11-04
по `main` на [`5581829`](https://github.com/axmadjan-777/solfege_app/commit/5581829d94d10ad38d0f5b0e8f6360afdfe8fbc9).
Основная карта дополнена обучающим маршрутом первого входа; изменения
документации и QA в PR #14 не меняют код приложения.
Это карта реализации, а не подтверждение работы живого сервера или приёмки MVP.

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
| Профиль | Данные вошедшего пользователя и карточки нотного тренажёра | [ProfileScreen](../lib/features/profile/screens/profile_screen.dart), [NoteTrainerScreen](../lib/features/note_trainer/screens/note_trainer_screen.dart) |

При первом входе [CoachController](../lib/features/coach/coach_controller.dart)
и [CoachOverlay](../lib/features/coach/coach_layer.dart) показывают восемь шагов
по теории, первому уроку и карте практики. Пропуск или завершение сохраняется
на устройстве в SharedPreferences (`coach_route_v1`); это состояние подсказок,
а не учебный прогресс.

Общие виджеты заданий находятся в [interaction](../lib/features/interaction/).
Условия открытия учебных экранов и найденные разрывы интеграции рассматриваются
в APP-01 и APP-04 roadmap.

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
| Учебный прогресс | SharedPreferences, ключ `practice_progress_v1`, по умолчанию `userId=local` | [PracticeProgressBinding](../lib/features/practice/progress/practice_progress_binding.dart), [ProgressStore](../lib/features/practice/progress/progress_store.dart) |
| История чата | Список сообщений в памяти экрана | [AiChatScreen](../lib/features/ai/screens/ai_chat_screen.dart) |

Профиль сохраняется в облаке, а учебный прогресс этой версии — на устройстве.
Облачная синхронизация и разделение локального ключа по аккаунтам здесь не
реализованы; задача изоляции — APP-02 в roadmap. Код облачной книги из другого
открытого PR нельзя считать поведением этой версии.

[schema.sql](../supabase/schema.sql) описывает профиль, песни, прогресс песен и RLS.
Отдельная [миграция нотного тренажёра](../supabase/migrations/202611050003_note_trainer.sql)
создаёт пять мотивов и `user_progress`. [SongRepository](../lib/features/note_trainer/data/song_repository.dart)
проверяет владельца сессии до и после запроса, закрепляет его токен за запросом
и записывает завершение одним upsert по `(user_id, song_id)`: повтор не удваивает 50 XP.
Ошибка облачного чтения не подменяется пустым локальным прогрессом, а ошибка
записи оставляет результат неподтверждённым и предлагает повторить сохранение.
Режим с `MemorySongRepository` явно сообщает, что данные живут только в этой сессии.
Смена аккаунта отменяет применение старых ответов, очищает карточки разминки
и открытый тренажёр. Старая карточка профиля не перепривязывается молча к новому
пользователю: загрузка возобновляется после получения его данных от оболочки.

Пианино C4–G5 использует двадцать локальных MP3; энгармонические имена указывают
на один файл высоты. [AssetNotePlayer](../lib/features/note_trainer/audio/note_player.dart)
последовательно выполняет stop/play и пропускает устаревшие запросы после ожидания.
Освобождение плеера отменяет очередь и закрывает принадлежащий ему backend один раз.
[Проверка медиа](../tool/verify_note_audio.py) декодирует каждый
файл и измеряет частоту, но не подтверждает слышимость в браузере.
Применение SQL и приёмка двух аккаунтов на hosted Supabase проверяются отдельно:
локальный PostgreSQL и файлы миграции не доказывают состояние живого проекта.

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

Телефон или браузер общается с серверным посредником. Ключ Gemini остаётся на
сервере. Настройка модели и функции описана в README; доступность реального API
офлайн-тестами не подтверждается.
