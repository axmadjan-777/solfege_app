# Сольфеджио

Flutter-приложение для обучения музыке: теория, тренировка слуха и музыкальный
ИИ-помощник. Этот README помогает настроить и запустить проект.
Описание работающего кода — в [architecture.md](docs/architecture.md),
задачи и границы приёмки — в [roadmap](docs/product_roadmap.md).

<a id="documentation-map"></a>

## Карта документации

Каждый вид сведений подробно хранится в одном месте. Остальные документы дают
ссылку или краткий указатель. Обновляет документ автор изменения в том же PR;
ревьюер проверяет соответствие. Перечитывать и обновлять все файлы после каждой
задачи не требуется.

| Документ | На какой вопрос отвечает | Когда обновлять |
|---|---|---|
| [README.md](README.md) | Как запустить проект? Где искать остальное? | Изменились настройка, команды, публикация или карта документов |
| [AGENTS.md](AGENTS.md) | Как агент выполняет одну задачу и какие границы соблюдает? | Изменились постоянный процесс, условия завершения или границы действий |
| [docs/architecture.md](docs/architecture.md) | Как устроено реализованное приложение и куда идут данные? | Изменились модули, точки входа, сервисы, потоки или хранение |
| [docs/product_roadmap.md](docs/product_roadmap.md) | Что предстоит сделать и как это принять? | Изменились приоритет, согласованный объём или доказанный статус задачи |
| [docs/decisions.md](docs/decisions.md) | Почему выбран существенный подход и что отвергнуто? | Принято или пересмотрено решение; изменился статус его внедрения |
| [docs/task-prompt.md](docs/task-prompt.md) | Как сформулировать одну задачу? | Изменились поля или примеры постановки задачи |
| [docs/curriculum/README.md](docs/curriculum/README.md) | Как найти и безопасно изменить учебные требования и данные? | Изменились навигация, источник генерации или порядок работы с контентом |
| [docs/curriculum/spec.md](docs/curriculum/spec.md) | Чему и по каким правилам учим? Какие исходные данные используем? | Согласовано изменение методики, содержания или схем; JSON затем извлекаются заново |
| [docs/archive/mvp-implementation-plan.md](docs/archive/mvp-implementation-plan.md) | Что было записано в прежнем плане I0–I25? | Уточнены пояснения к прежнему продуктовому объёму |
| [iOS LaunchImage README](ios/Runner/Assets.xcassets/LaunchImage.imageset/README.md) | Как заменить ресурс стартового изображения iOS? | Изменился способ подготовки или подключения этого ресурса |

Новый документ нужен, когда появляется отдельный вопрос и читатель. Для истории
задачи достаточно PR и Git; общие STATE/MEMORY/SESSIONS здесь не ведутся.
Новые обычные документы называются по роли в `docs/` в нижнем регистре; слова
разделяются дефисом. Стандартные `AGENTS.md` и `README.md` сохраняют имена.
Существующие понятные пути `product_roadmap.md` и `curriculum/spec.md` не
переименовываются ради оформления. Обоснование структуры — D-001 в журнале решений.

## Требования и SDK

- Версия **Flutter** закреплена в [tool/toolchain.env](tool/toolchain.env).
- Git и Bash нужны для работы с проектом. Python 3 используется для извлечения учебных данных.
- `environment.sdk` в `pubspec.yaml` задаёт диапазон **Dart**.
- Android/iOS SDK нужны для соответствующих сборок.

Установите закреплённую версию из [Flutter SDK](https://docs.flutter.dev/install/archive).
[Выбор SDK](tool/toolchain.sh) использует явно заданный `FLUTTER_BIN`, затем
локальную версию в `$HOME/.local/share/solfege_app/toolchains/flutter-<версия>/bin/flutter`,
затем PATH и резервный `$HOME/flutter/bin/flutter`. Локальный каталог можно
переопределить через `SOLFEGE_TOOLCHAIN_DIR`.

```bash
source tool/toolchain.sh
"$FLUTTER_BIN" pub get --enforce-lockfile
```

Для нестандартного пути передайте `FLUTTER_BIN=/path/to/flutter/bin/flutter`.
Для IDE выберите тот же SDK. Обновление зависимостей — отдельное изменение
`pubspec.yaml` и `pubspec.lock`.

## Запуск приложения

Один раз создайте локальную конфигурацию:

```bash
cp dart_defines.example.json dart_defines.json
# Вставьте publishable / anon key из Supabase Dashboard → Project Settings → API
./run_web.sh
```

Не заменяйте уже настроенный файл шаблоном. Он исключён из Git. `service_role`
и Gemini API key нельзя передавать во Flutter или включать в web-сборку.
Перед инициализацией клиент принимает только publishable / anon key; секретный
ключ или токен управления показывает ошибку конфигурации и блокирует подключение.

Другие способы запуска после выбора SDK:

```bash
source tool/toolchain.sh
"$FLUTTER_BIN" run -d chrome --dart-define-from-file=dart_defines.json
```

В Cursor/VS Code есть конфигурации в [.vscode/launch.json](.vscode/launch.json).
Для доступа к основному интерфейсу укажите ключи Supabase в локальной конфигурации.

После изменения `dart_defines.json` полностью перезапустите приложение:
hot reload не перечитывает `--dart-define`. В zsh не оставляйте пустую строку
после завершающего строку `\`. Остановка — `q`/Ctrl+C в терминале запуска или
`./stop_web.sh`; скрипт посылает SIGTERM только Flutter web-серверу с рабочим
каталогом этой копии, не всем копиям проекта на машине.

## Supabase и Gemini

Базовая конфигурация проекта — [supabase/config.toml](supabase/config.toml),
схема профиля и RLS — [supabase/schema.sql](supabase/schema.sql).
Облачный прогресс устанавливается отдельной
[миграцией](supabase/migrations/202611050001_cloud_progress.sql) после базовой
схемы профиля, затем
[исправлением кода конфликта](supabase/migrations/202611050004_cloud_progress_conflict.sql).
Нужны обе миграции в порядке номера; применённая `001` остаётся неизменной
историей. Они содержат таблицы, RLS, историю версий и атомарный RPC;
прямой клиентский `delete`/`insert` таблиц прогресса запрещён.
Настройка живого проекта и применение SQL — отдельная операция с разрешением. Состояние файлов не доказывает,
что та же схема уже применена на сервере.

Для нового окружения:

1. Примените схему профиля к выбранной БД. Триггер создаёт профиль
   при регистрации; onboarding-поля допускают `null`, затем заполняются upsert.
2. Включите Email provider и настройте confirmation/reset письма. Для реальных
   пользователей настройте SMTP; текущие лимиты проверяйте в панели Supabase.
3. Для существующего production-сайта Site URL —
   `https://axmadjan-777.github.io/solfege_app/`, Redirect URLs включают
   `https://axmadjan-777.github.io/solfege_app/**`. Для другого окружения проверьте
   также redirect URL в клиенте.
4. Сохраните publishable / anon key в локальном `dart_defines.json`.

Телефонный вход отключён в интерфейсе; Phone provider для текущего сценария
не нужен. Apple Sign-In требует отдельной настройки Apple Developer и provider
в Supabase; секрет Apple остаётся на сервере.

Устройство auth-сценария описано в [architecture.md](docs/architecture.md).

Для ИИ серверу нужен `GEMINI_API_KEY` в Edge Functions Secrets. Значение
`GEMINI_MODEL` переопределяет модель; дефолт в коде — `gemini-3.1-flash-lite`.
Развёртывание функции, когда оно входит в задачу:

```bash
supabase functions deploy gemini-chat --project-ref zehmcszijutthmeswtci
```

Новые возможности БД поставляются отдельными версионированными SQL-файлами
в [supabase/migrations](supabase/migrations/). Их применяют к выбранному проекту
до публикации соответствующего клиента.

## Публикация

[Deploy Flutter Web](.github/workflows/deploy_web.yml) запускается при push в
`main` или вручную для `main`. Workflow использует закреплённый Flutter,
собирает web с GitHub secrets `SUPABASE_URL` и `SUPABASE_PUBLISHABLE_KEY`
и публикует результат в GitHub Pages. Состояние публикации доступно
в окружении `github-pages`.

## Запуск на телефоне

Выберите закреплённый SDK, подключите устройство и выполните `flutter devices`.
Запускайте с `--dart-define-from-file=dart_defines.json`.
