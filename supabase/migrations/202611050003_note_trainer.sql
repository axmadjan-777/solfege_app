begin;

-- Нотный тренажёр: пять мотивов и прогресс игрока.

create table if not exists public.songs (
  id text primary key,
  title text not null,
  artist text not null,
  difficulty text not null check (difficulty in ('easy', 'medium', 'hard')),
  expected_notes text[] not null,
  note_positions int[] not null,
  constraint songs_notes_shape check (
    cardinality(expected_notes) > 0
    and cardinality(expected_notes) = cardinality(note_positions)
  )
);

create table if not exists public.user_progress (
  user_id uuid not null references auth.users (id) on delete cascade,
  song_id text not null references public.songs (id) on delete cascade,
  is_completed boolean not null default false,
  score integer not null default 0,
  primary key (user_id, song_id),
  constraint user_progress_completion_score check (
    (is_completed and score = 50) or (not is_completed and score = 0)
  )
);

create index if not exists user_progress_user_idx
  on public.user_progress (user_id);

alter table public.songs enable row level security;
alter table public.user_progress enable row level security;

-- Also remove Supabase default grants: TRUNCATE is not protected by RLS.
revoke all on table public.songs from public, anon, authenticated;
revoke all on table public.user_progress from public, anon, authenticated;

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

-- Existing installations receive the same constraints as a fresh schema.
alter table public.songs drop constraint if exists songs_notes_shape;
alter table public.songs add constraint songs_notes_shape check (
  cardinality(expected_notes) > 0
  and cardinality(expected_notes) = cardinality(note_positions)
);
alter table public.user_progress drop constraint if exists user_progress_completion_score;
alter table public.user_progress add constraint user_progress_completion_score check (
  (is_completed and score = 50) or (not is_completed and score = 0)
);

commit;
