-- Idempotent schema for solfege_app profiles.
-- Run manually in Supabase SQL Editor.

create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  display_name text,
  age int check (age is null or age between 6 and 90),
  musician_level text check (
    musician_level is null
    or musician_level in ('beginner', 'pro', 'expert')
  ),
  onboarding_completed boolean not null default false,
  preferred_note_language text not null default 'ru_solfege',
  gender text check (gender in ('male', 'female', 'other', 'prefer_not_say')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Existing installations: relax NOT NULL so a profile row can be created at
-- sign-up time (e.g. phone OTP) before onboarding is filled in. If these
-- columns stay NOT NULL, an AFTER INSERT trigger on auth.users that bootstraps
-- a profile will violate the constraint and roll back the *whole* auth sign-up
-- transaction — leaving the user missing from auth.users entirely.
alter table public.profiles alter column display_name drop not null;
alter table public.profiles alter column age drop not null;
alter table public.profiles alter column musician_level drop not null;

alter table public.profiles enable row level security;

drop policy if exists "Users can read own profile" on public.profiles;
create policy "Users can read own profile"
  on public.profiles
  for select
  using (auth.uid() = id);

drop policy if exists "Users can insert own profile" on public.profiles;
create policy "Users can insert own profile"
  on public.profiles
  for insert
  with check (auth.uid() = id);

drop policy if exists "Users can update own profile" on public.profiles;
create policy "Users can update own profile"
  on public.profiles
  for update
  using (auth.uid() = id)
  with check (auth.uid() = id);

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists profiles_set_updated_at on public.profiles;
create trigger profiles_set_updated_at
  before update on public.profiles
  for each row
  execute function public.set_updated_at();

-- Bootstrap a profile row whenever a new auth user is created (email, phone,
-- OAuth, ...). Runs as SECURITY DEFINER so it bypasses RLS, and never throws:
-- if profile creation fails for any reason it must NOT abort the auth.users
-- insert, otherwise the user would never be created in Supabase Auth.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_meta jsonb := coalesce(new.raw_user_meta_data, '{}'::jsonb);
  v_age int;
begin
  begin
    v_age := nullif(v_meta ->> 'age', '')::int;
  exception when others then
    v_age := null;
  end;

  insert into public.profiles (id, display_name, age, musician_level)
  values (
    new.id,
    nullif(v_meta ->> 'display_name', ''),
    case when v_age between 6 and 90 then v_age end,
    case
      when (v_meta ->> 'musician_level') in ('beginner', 'pro', 'expert')
        then v_meta ->> 'musician_level'
    end
  )
  on conflict (id) do nothing;

  return new;
exception when others then
  -- Swallow any error: a broken profile bootstrap must never block sign-up.
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row
  execute function public.handle_new_user();

-- Книга прогресса и разложенные попытки. Клиент пишет их после каждой сессии.
-- anon не имеет прав: прогресс только у вошедшего пользователя.

create table if not exists public.practice_books (
  user_id uuid primary key references auth.users (id) on delete cascade,
  book jsonb not null,
  updated_at timestamptz not null default now()
);

create table if not exists public.practice_attempts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  competency_id text not null,
  session_id text not null,
  item_signature text not null,
  error_tag text not null default '',
  is_correct boolean not null,
  response_ms int not null default 0,
  hints_used int not null default 0,
  replays int not null default 0,
  tonality text not null default 'C',
  critical boolean not null default false,
  cold_review boolean not null default false,
  transfer boolean not null default false,
  created_at timestamptz not null default now()
);

create index if not exists practice_attempts_user_created_idx
  on public.practice_attempts (user_id, created_at desc);

create table if not exists public.practice_competencies (
  user_id uuid not null references auth.users (id) on delete cascade,
  competency_id text not null,
  status text not null,
  interval_step int not null default 0,
  due_at timestamptz,
  provisional_at timestamptz,
  stability jsonb not null default '[]'::jsonb,
  updated_at timestamptz not null default now(),
  primary key (user_id, competency_id)
);

create table if not exists public.practice_returns (
  user_id uuid not null references auth.users (id) on delete cascade,
  tag text not null,
  due_at timestamptz not null,
  primary key (user_id, tag)
);

alter table public.practice_books enable row level security;
alter table public.practice_attempts enable row level security;
alter table public.practice_competencies enable row level security;
alter table public.practice_returns enable row level security;

revoke all on table public.practice_books from anon;
revoke all on table public.practice_attempts from anon;
revoke all on table public.practice_competencies from anon;
revoke all on table public.practice_returns from anon;

grant select, insert, update, delete on table public.practice_books to authenticated;
grant select, insert, update, delete on table public.practice_attempts to authenticated;
grant select, insert, update, delete on table public.practice_competencies to authenticated;
grant select, insert, update, delete on table public.practice_returns to authenticated;

drop policy if exists "practice_books_own" on public.practice_books;
create policy "practice_books_own"
  on public.practice_books
  for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "practice_attempts_own" on public.practice_attempts;
create policy "practice_attempts_own"
  on public.practice_attempts
  for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "practice_competencies_own" on public.practice_competencies;
create policy "practice_competencies_own"
  on public.practice_competencies
  for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "practice_returns_own" on public.practice_returns;
create policy "practice_returns_own"
  on public.practice_returns
  for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- История музыкального чата. Одна сессия на пользователя, сообщения только свои.

create table if not exists public.ai_chat_sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  created_at timestamptz not null default now()
);

create index if not exists ai_chat_sessions_user_created_idx
  on public.ai_chat_sessions (user_id, created_at desc);

create table if not exists public.ai_chat_messages (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null references public.ai_chat_sessions (id) on delete cascade,
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  role text not null check (role in ('user', 'model')),
  body text not null check (char_length(body) between 1 and 8000),
  created_at timestamptz not null default now()
);

create index if not exists ai_chat_messages_session_created_idx
  on public.ai_chat_messages (session_id, created_at);

alter table public.ai_chat_sessions enable row level security;
alter table public.ai_chat_messages enable row level security;

revoke all on table public.ai_chat_sessions from anon;
revoke all on table public.ai_chat_messages from anon;

grant select, insert, update, delete on table public.ai_chat_sessions to authenticated;
grant select, insert, update, delete on table public.ai_chat_messages to authenticated;

drop policy if exists "ai_chat_sessions_own" on public.ai_chat_sessions;
create policy "ai_chat_sessions_own"
  on public.ai_chat_sessions
  for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "ai_chat_messages_own" on public.ai_chat_messages;
create policy "ai_chat_messages_own"
  on public.ai_chat_messages
  for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- Нотный тренажёр: пять мотивов и прогресс игрока.

create table if not exists public.songs (
  id text primary key,
  title text not null,
  artist text not null,
  difficulty text not null check (difficulty in ('easy', 'medium', 'hard')),
  expected_notes text[] not null,
  note_positions int[] not null
);

create table if not exists public.user_progress (
  user_id uuid not null references auth.users (id) on delete cascade,
  song_id text not null references public.songs (id) on delete cascade,
  is_completed boolean not null default false,
  score integer not null default 0,
  primary key (user_id, song_id)
);

create index if not exists user_progress_user_idx
  on public.user_progress (user_id);

alter table public.songs enable row level security;
alter table public.user_progress enable row level security;

revoke all on table public.songs from anon;
revoke all on table public.user_progress from anon;

grant select on table public.songs to anon, authenticated;
grant select, insert, update, delete on table public.user_progress to authenticated;

drop policy if exists "songs_read" on public.songs;
create policy "songs_read"
  on public.songs
  for select
  to anon, authenticated
  using (true);

drop policy if exists "user_progress_own" on public.user_progress;
create policy "user_progress_own"
  on public.user_progress
  for all
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

insert into public.songs (id, title, artist, difficulty, expected_notes, note_positions)
values
  ('yesterday', 'Yesterday', 'The Beatles', 'easy', array['G4','F4','F4'], array[4,3,3]),
  ('bohemian-rhapsody', 'Bohemian Rhapsody', 'Queen', 'medium', array['Bb4','D5','F5'], array[3,5,7]),
  ('smells-like-teen-spirit', 'Smells Like Teen Spirit', 'Nirvana', 'medium', array['C4','Eb4','F4'], array[0,2,3]),
  ('billie-jean', 'Billie Jean', 'Michael Jackson', 'hard', array['F#4','C#4','E4','F#4'], array[3,0,2,3]),
  ('i-will-always-love-you', 'I Will Always Love You', 'Whitney Houston', 'easy', array['A4','F#4','E4','A4'], array[5,3,2,5])
on conflict (id) do update set
  title = excluded.title,
  artist = excluded.artist,
  difficulty = excluded.difficulty,
  expected_notes = excluded.expected_notes,
  note_positions = excluded.note_positions;
