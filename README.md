# Сольфеджио

Flutter-приложение для тренировки слуха музыкантов: гаммы, сольфеджио-нотация, onboarding и авторизация через Supabase.

## Требования

- Flutter SDK ^3.5.0
- Supabase project (ref: `zehmcszijutthmeswtci`)

## Запуск

Один раз настройте ключи (файл в `.gitignore`, в git не попадёт):

```bash
flutter pub get
cp dart_defines.example.json dart_defines.json
# Вставьте publishable key в dart_defines.json
```

Дальше каждый запуск — **короткая команда**, без длинных `--dart-define`:

```bash
./run_web.sh
```

Или вручную (то же самое):

```bash
flutter run -d web-server --dart-define-from-file=dart_defines.json
```

В Cursor/VS Code: **Run and Debug → Web Server (Safari)** — ключи подставятся сами.

Для Chrome вместо Safari:

```bash
flutter run -d chrome --dart-define-from-file=dart_defines.json
```

Замените `YOUR_PUBLISHABLE_KEY` на **publishable key** из Supabase Dashboard → Project Settings → API.

> **zsh:** пустая строка после `\` обрывает команду — `flutter run` стартует без `--dart-define`.
>
> **Hot reload не подхватывает** `--dart-define`. После смены ключей: `q` → полный перезапуск.

> **Важно:** secret key (`service_role`) нельзя использовать в Flutter-коде, добавлять в репозиторий или передавать через `--dart-define`.

## Настройка Supabase

### 1. SQL schema

Выполните [`supabase/schema.sql`](supabase/schema.sql) в SQL Editor.

Скрипт создаёт таблицу `profiles`, RLS-политики и **триггер `on_auth_user_created`**,
который автоматически заводит строку в `profiles` при создании пользователя в
`auth.users` (email, телефон, OAuth).

> **Важно про телефонную регистрацию.** Колонки `display_name`, `age`,
> `musician_level` сделаны **nullable**. Если оставить их `NOT NULL`, то любой
> триггер `AFTER INSERT ON auth.users`, который создаёт профиль, упадёт на
> ограничении и **откатит всю транзакцию регистрации** — пользователь не
> появится в `auth.users` (но строка в `profiles` может остаться от прошлой
> попытки). Поэтому `handle_new_user()` объявлен как `security definer`,
> `set search_path = ''` и **никогда не бросает исключение** (любая ошибка
> проглатывается, чтобы не блокировать создание auth-пользователя). Если вы
> ранее заводили свой триггер на `auth.users`, замените его этим вариантом или
> убедитесь, что он не нарушает `NOT NULL`/`CHECK`.

### 2. Phone Auth (SMS OTP)

Authentication → Providers → **Phone**:

1. Включите **Phone**.
2. Подключите SMS-провайдера (Twilio / MessageBird / Vonage и т.д.) и заполните
   ключи. Без провайдера `signInWithOtp(phone)` вернёт ошибку и SMS не уйдёт.
3. Authentication → **Sign In / Providers** → убедитесь, что включён
   **Allow new users to sign up** (иначе `shouldCreateUser: true` вернёт
   `Signups not allowed`).
4. Twilio trial: номер получателя должен быть в **Verified Caller IDs**.

Flutter-флоу: `signInWithOtp(phone, shouldCreateUser: true, data: metadata)` →
`verifyOTP(type: sms)` → upsert профиля. Onboarding-данные кладутся в
`raw_user_meta_data`, поэтому триггер сразу заполняет ими `profiles`.

### 3. Email Auth

Authentication → Providers:

1. Включите **Email**.
2. **Confirm email** — для продакшена включено; для локальной разработки можно временно отключить.
3. Настройте email templates для confirmation и reset password.

### 4. Publishable key

Скопируйте **publishable / anon** key. Secret key в клиент не добавлять.

## Email confirmation flow

После регистрации с включённым подтверждением email:

1. Onboarding-данные сохраняются в `user_metadata` и локально (`shared_preferences`).
2. Показывается экран **«Подтвердите email»**.
3. **Resend** — повторная отправка письма, таймер 60 секунд между отправками.
4. После подтверждения (ссылка в письме или вход) создаётся `profiles` через upsert.
5. Один раз показывается экран **«Email подтверждён»** → кнопка **«Старт»** → основное приложение.

Если письмо не приходит: проверьте Spam, Resend после таймера, настройки SMTP в Supabase.

## Manual Apple Sign-In setup

1. Apple Developer Account.
2. App ID с **Sign in with Apple**.
3. Services ID + redirect URLs для web/OAuth.
4. Key (`.p8`) и client secret — **только на сервере / в Supabase Dashboard**, не в Flutter.
5. Supabase → Authentication → Apple → Enable.
6. Redirect: `https://zehmcszijutthmeswtci.supabase.co/auth/v1/callback` + localhost для dev.

## Архитектура

```
lib/features/
├── auth/     # onboarding, AuthGate, email verification, profiles
└── scales/   # гаммы, тональности, ScaleAudioPlayer
```

- **AuthGate** — state machine: config → auth → email pending → profile → app.
- **ProfileService.ensureCurrentUserProfile** — upsert из onboarding / metadata / pending store.
- **ScaleToneAudioService** — программная генерация тонов (без audio-файлов).

## Product roadmap

См. [`docs/product_roadmap.md`](docs/product_roadmap.md).

### Готово

- Onboarding + auth + profiles (RLS)
- Email verification pending + resend + one-shot success screen
- Гаммы (русская сольфеджио-нотация, ключевые знаки)
- Audio MVP: вверх / вниз / вверх-вниз через синтез тонов

### Дальше

- Диктант ступеней, интервалы, трезвучия, секстаккорд, квартсекстаккорд
- Уменьшённые/увеличенные трезвучия, теория, audio engine v2

## Тест на телефоне

1. Подключите iPhone или Android, проверьте: `flutter devices`.
2. Запускайте **только** с ключами Supabase:
   ```bash
   flutter run --dart-define-from-file=dart_defines.json
   ```
   Или в Cursor/VS Code: **Run → Android (телефон)** / **iOS (iPhone)** — конфиг в `.vscode/launch.json`.
3. **Звук:** на iPhone включите громкость (режим «без звука» может глушить тоны, если не настроен playback).
4. **SMS (Twilio trial):** номер получателя должен быть добавлен в Verified Caller IDs в Twilio.
5. **Email на телефоне:** ссылка из письма откроется в браузере; после подтверждения войдите в приложении вручную.

> Не разбивайте команду `flutter run` на несколько строк с `\` — zsh обрежет `--dart-define`.

## Проверка

```bash
flutter analyze
flutter test
```
