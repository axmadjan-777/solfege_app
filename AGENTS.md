# AGENTS.md

## Cursor Cloud specific instructions

### Product overview

Single Flutter web/mobile client (`solfege_app`) for ear training (scales, solfège notation, auth). There is no backend in this repo — auth and profiles use hosted **Supabase** (`https://zehmcszijutthmeswtci.supabase.co`).

### Toolchain

- **Flutter SDK** is installed at `$HOME/flutter` (stable channel). `~/.bashrc` adds it to `PATH`.
- Use `"$HOME/flutter/bin/flutter"` if a non-login shell does not pick up `PATH`.
- **Web development** works out of the box (Chrome is available). Android SDK and Linux desktop GTK deps are **not** installed; mobile/desktop builds are optional.

### First-time secrets (required for auth / full app flow)

Create `dart_defines.json` from the template (gitignored):

```bash
cp dart_defines.example.json dart_defines.json
# Set SUPABASE_PUBLISHABLE_KEY from Supabase Dashboard → Project Settings → API
```

Without this file, the app runs but shows **«Supabase не настроен»**. Offline unit/widget tests do not need Supabase.

### Common commands

| Task | Command |
|------|---------|
| Install deps | `flutter pub get` |
| Lint / analyze | `flutter analyze` |
| Tests | `flutter test` |
| Run web (preferred) | `./run_web.sh` |
| Run web (manual) | `flutter run -d web-server --dart-define-from-file=dart_defines.json` |
| Run Chrome | `flutter run -d chrome --dart-define-from-file=dart_defines.json` |
| Stop web-server | `./stop_web.sh` |

See [README.md](README.md) for Supabase schema, email auth, and deployment details.

### Running the web app in Cloud Agent VMs

- `./run_web.sh` requires a valid `dart_defines.json` (not the `YOUR_PUBLISHABLE_KEY` placeholder).
- For smoke tests without keys: `flutter run -d web-server --web-port=8080 --web-hostname=0.0.0.0` — serves at `http://127.0.0.1:8080` with the config-error screen.
- **Hot reload does not apply `--dart-define` changes**; quit (`q`) and restart after editing `dart_defines.json`.
- Long-running `flutter run` should use **tmux** (see cloud agent shell guidelines).

### External services

| Service | Required for | Notes |
|---------|--------------|-------|
| Supabase cloud | Auth, profiles, E2E login | Apply `supabase/schema.sql` once in SQL Editor |
| Twilio (via Supabase) | Phone OTP only | Optional |
| GitHub Pages | Production deploy | CI only; not needed for local dev |

### Gotchas

- Do not commit `dart_defines.json` or use the **service_role** secret in the client.
- `run_web.sh` exits early if keys are missing or still templated.
- zsh users: blank lines after `\` break multi-line `flutter run` commands (see README).
