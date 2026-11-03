# Сольфеджио

Flutter-приложение для обучения музыке. В основном интерфейсе пять вкладок:
**Гаммы, Теория, Практика, ИИ, Профиль**. Авторизация и профиль используют
Supabase; серверный посредник для Gemini также находится в этом репозитории.

Код приложения описан по `main` на `5581829` (сверка 2026-11-04). Есть реализованные
уроки и тренажёры, но весь учебный путь ещё нельзя считать принятым: известные
ограничения и критерии следующих задач — в [roadmap](docs/product_roadmap.md).
Обновлять README вместе с изменением запуска, архитектуры, хранения или проверок.

## Быстрая навигация

- [Правила агентского цикла](AGENTS.md): одна согласованная задача, проверки,
  документация, затем разрешённые Git-действия.
- [Промпт задачи](docs/curriculum/AGENT_PROMPT.md): шаблон запроса и правила контента.
- [Roadmap](docs/product_roadmap.md): реализация, пробелы приёмки, отдельные PR.
- [Архив I0–I25](docs/curriculum/MVP_IMPLEMENTATION_PLAN.md): прежние решения;
  не инструкция на автоматическое продолжение разработки.

## Требования и SDK

- Точные версии **Flutter и Deno** — в [tool/toolchain.env](tool/toolchain.env).
  Flutter закреплён по успешному [CI-прогону](https://github.com/axmadjan-777/solfege_app/actions/runs/37341857670).
- Git, Bash, Python 3. Для полного web-сценария — браузер и тестовый аккаунт.
- `environment.sdk` в `pubspec.yaml` задаёт диапазон **Dart**, не версию Flutter.
  Используйте закреплённый Flutter, совместимый с существующим `pubspec.lock`.
- Android/iOS SDK нужны только для соответствующих сборок, не для основного QA.

Установите указанные версии из [Flutter SDK](https://docs.flutter.dev/install/archive)
и [Deno releases](https://github.com/denoland/deno/releases). Общий
[выбор SDK](tool/toolchain.sh) использует явно заданные `FLUTTER_BIN`/`DENO_BIN`,
затем локальные версии в `$HOME/.local/share/solfege_app/toolchains/`, затем PATH
и резервные `$HOME/flutter/bin/flutter`, `$HOME/.deno/bin/deno`.
В локальном каталоге ожидаются `flutter-<версия>/bin/flutter` и
`deno-<версия>/deno`; его можно переопределить через `SOLFEGE_TOOLCHAIN_DIR`.
Харнесс не устанавливает и не обновляет SDK самостоятельно.

```bash
source tool/toolchain.sh
"$FLUTTER_BIN" pub get --enforce-lockfile
bash tool/install_hooks.sh
bash tool/verify.sh
```

Для нестандартного пути передайте, например, `FLUTTER_BIN=/path/to/flutter/bin/flutter`.
Для IDE отдельно выберите тот же SDK. Обновление зависимостей — отдельное
согласованное изменение; обычная проверка не переписывает `pubspec.lock`.

## Запуск приложения

Один раз создайте локальную конфигурацию:

```bash
cp dart_defines.example.json dart_defines.json
# Вставьте publishable / anon key из Supabase Dashboard → Project Settings → API
./run_web.sh
```

Не заменяйте уже настроенный файл шаблоном. Он исключён из Git. `service_role`
и Gemini API key нельзя передавать во Flutter или включать в web-сборку.

Другие способы запуска после выбора SDK:

```bash
source tool/toolchain.sh
"$FLUTTER_BIN" run -d chrome --dart-define-from-file=dart_defines.json
```

В Cursor/VS Code есть конфигурации в [.vscode/launch.json](.vscode/launch.json).
Без ключей приложение показывает «Supabase не настроен». Это ожидаемо для
проверки запуска, но не открывает основной интерфейс.

После изменения `dart_defines.json` полностью перезапустите приложение:
hot reload не перечитывает `--dart-define`. В zsh не оставляйте пустую строку
после завершающего строку `\`. Остановка — `q`/Ctrl+C в терминале запуска или
`./stop_web.sh`; скрипт посылает SIGTERM только Flutter web-серверу с рабочим
каталогом этой копии, не всем копиям проекта на машине.

## Как устроено приложение

Старт: [main.dart](lib/main.dart) → [app.dart](lib/app.dart) →
[AuthGate](lib/features/auth/screens/auth_gate.dart) →
[MainShellScreen](lib/features/app/main_shell_screen.dart).
AuthGate проверяет конфигурацию, вход, подтверждение email и профиль, затем
показывает основное приложение.

| Часть | Простыми словами | Где смотреть |
|---|---|---|
| Гаммы | Выбор тональности, ноты, проигрывание вверх/вниз | [scales](lib/features/scales/) |
| Теория | Карта уроков, объяснения и задания | [theory](lib/features/theory/) |
| Практика | Карта тренажёров и учебные сессии | [practice](lib/features/practice/) |
| ИИ | Чат с музыкальным помощником | [ai](lib/features/ai/) |
| Профиль | Данные вошедшего пользователя | [profile](lib/features/profile/), [auth](lib/features/auth/) |
| Учебный каталог | Содержание программы и связи между темами | [curriculum](lib/features/curriculum/), [assets](assets/curriculum/) |
| Общие задания | Виджеты, используемые уроками и тренажёрами | [interaction](lib/features/interaction/) |

**Уроки и упражнения** встроены в приложение как шесть JSON-файлов.
[CurriculumAssetSource](lib/features/curriculum/data/curriculum_asset_source.dart)
читает их через Flutter assets, а не скачивает с сервера. Каталог содержит
114 уроков, из них 56 отмечены как MVP; это объём данных, не число принятых сценариев.
Исходные JSON-блоки и требования — в [спецификации](docs/curriculum/spec.md).
Порядок изменения содержания описан в промпте задачи; чтение всей спецификации
для обычной задачи не требуется.

**Профиль и учебный прогресс хранятся по-разному.**
[ProfileService](lib/features/auth/services/profile_service.dart) читает и
обновляет Supabase `public.profiles`. Данные незавершённой регистрации также
временно сохраняются локально. Учебный прогресс подключается через
[PracticeProgressBinding](lib/features/practice/progress/practice_progress_binding.dart)
и [SharedPreferencesProgressStore](lib/features/practice/progress/progress_store.dart):
в текущем `main` это локальный `practice_progress_v1`, по умолчанию `userId=local`.
Синхронизации между устройствами и разделения этого ключа по аккаунтам нет.

**Звук гаммы**: кнопка на
[экране гаммы](lib/features/scales/screens/scale_detail_screen.dart) →
[ScalePlayback](lib/features/scales/logic/scale_playback.dart) →
[ScaleToneAudioService](lib/features/scales/services/scale_tone_audio_service.dart)
→ [ToneGenerator](lib/features/scales/services/tone_generator.dart).
Последовательность нот превращается в WAV в памяти и воспроизводится через
`audioplayers`; скачивание звуков для этого пути не требуется.

**Сообщение ИИ**: [экран чата](lib/features/ai/screens/ai_chat_screen.dart) →
сервис клиента → [gemini-chat](supabase/functions/gemini-chat/index.ts) → Gemini.
Edge Function проверяет Supabase-сессию, берёт последние 12 сообщений, добавляет
[серверную инструкцию](supabase/functions/gemini-chat/master_prompt.ts) и возвращает
ответ. История чата в текущем `main` находится в памяти экрана. Облачный прогресс,
история чата и другие изменения открытого PR #13 не считаются частью `main`.

## Supabase и Gemini

Базовая конфигурация проекта — [supabase/config.toml](supabase/config.toml),
схема профиля и RLS — [supabase/schema.sql](supabase/schema.sql).
Настройка живого проекта и применение SQL — отдельная операция с разрешением,
не часть `verify.sh` или установки hooks. Состояние файлов не доказывает,
что та же схема уже применена на сервере.

Для нового окружения:

1. Примените схему профиля к выбранной тестовой БД. Триггер создаёт профиль
   при регистрации; onboarding-поля допускают `null`, затем заполняются upsert.
2. Включите Email provider и настройте confirmation/reset письма. Для реальных
   пользователей настройте SMTP; текущие лимиты проверяйте в панели Supabase.
3. Для существующего production-сайта Site URL —
   `https://axmadjan-777.github.io/solfege_app/`, Redirect URLs включают
   `https://axmadjan-777.github.io/solfege_app/**`. Для другого окружения проверьте
   также redirect URL в клиенте. Не меняйте общую production-настройку ради теста.
4. Сохраните publishable / anon key в локальном `dart_defines.json`.

Телефонный вход отключён в интерфейсе; Phone provider для текущего сценария
не нужен. Apple Sign-In требует отдельной настройки Apple Developer и provider
в Supabase; секрет Apple остаётся на сервере.

Email-сценарий: onboarding сохраняется в metadata и локально → ожидание
подтверждения с таймером повторной отправки → ссылка Supabase → сессия и профиль.
Клиент использует implicit flow, поддерживает ссылку с `token_hash` и восстановление
пароля. Ссылки, почту и конкурирующие события авторизации проверяют отдельно
на тестовом аккаунте; офлайн-тесты не подтверждают доставку писем.

Для ИИ серверу нужен `GEMINI_API_KEY` в Edge Functions Secrets. Значение
`GEMINI_MODEL` переопределяет модель; дефолт в коде — `gemini-3.1-flash-lite`.
Доступность модели и квоты конкретного проекта требуют живой проверки.
Развёртывание функции, когда оно входит в задачу:

```bash
supabase functions deploy gemini-chat --project-ref zehmcszijutthmeswtci
```

## Независимый QA и pre-commit

Общая команда — `bash tool/verify.sh`. Она проверяет версии SDK и выполняет:

1. Тесты самого Git-хука на временных репозиториях.
2. `flutter pub get --enforce-lockfile` и анализ без повторного `pub get`.
3. Сверку JSON с исходными блоками спецификации.
4. Все Flutter unit/widget-тесты.
5. Проверку типов TypeScript и тесты настоящего обработчика Edge Function
   с подменёнными Auth/Gemini, без сетевых и env-разрешений Deno.
6. Release-сборку web без production-ключей.

Любая ошибка останавливает пайплайн. QA не изменяет исходники; кэши и сборка
могут появляться в игнорируемых каталогах. SQL/RLS на живой БД, браузерный путь
после входа, реальный звук и ответ модели этим прогоном не проверяются.

Подключение один раз **в каждой рабочей копии**:

```bash
bash tool/install_hooks.sh
```

Установщик задаёт локальный `core.hooksPath=.githooks` и не заменяет чужие hooks.
[Pre-commit](.githooks/pre-commit) вызывает [qa_staged.sh](tool/qa_staged.sh):
снимок индекса распаковывается во временный каталог, там запускается общий QA.
Незастейдженные правки и локальные секреты туда не попадают. При ошибке или
изменении индекса во время проверки коммит блокируется; временная копия удаляется.
Для ручного запуска той же проверки: `bash tool/qa_staged.sh`.
Проверка может занять несколько минут. Это отдельный процесс проверки, не
автоматическое заключение второго ИИ-агента.

Хук срабатывает перед **коммитом**, а не на завершение любого ответа агента.
Перед завершением задачи без коммита агент запускает `tool/verify.sh` по AGENTS.md.
Git позволяет обойти локальный hook; независимая проверка в CI остаётся необходимой.

## CI и публикация

[Verify](.github/workflows/verify.yml) запускает тот же QA на push любой ветки,
на PR и вручную. Push-проверка покрывает коммит и при конфликтующем PR; она
не доказывает, что конфликт уже разрешён или merge безопасен.

[Deploy Flutter Web](.github/workflows/deploy_web.yml) для `main` сначала вызывает
тот же Verify, затем собирает сайт с GitHub secrets `SUPABASE_URL` и
`SUPABASE_PUBLISHABLE_KEY` и публикует Pages. Ручной deploy также ограничен `main`.
Проверка без ключей и production-сборка относятся к одному коммиту.

При аудите 2026-11-04 обязательная защита `main` не была настроена. Эти workflow
не включают её сами: требование успешного `Verify / verify` перед merge задаётся
отдельно в GitHub branch rules. До этого локальный hook и CI не запрещают все
способы прямой записи в `main`.

## Проверка на телефоне

Выберите закреплённый SDK, подключите устройство и проверьте `flutter devices`.
Запускайте с `--dart-define-from-file=dart_defines.json`. Отдельно проверьте звук,
авторизацию и возвращение по email-ссылке: в мобильном приложении ссылка может
открыться в браузере. Эти сценарии не входят в web-сборку харнесса.
