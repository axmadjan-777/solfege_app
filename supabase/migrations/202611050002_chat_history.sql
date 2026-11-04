begin;

create table if not exists public.ai_chat_sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  created_at timestamptz not null default now()
);

create index if not exists ai_chat_sessions_user_created_idx
  on public.ai_chat_sessions (user_id, created_at desc);

-- Composite ownership prevents a user's message being attached to another user's session.
create unique index if not exists ai_chat_sessions_id_user_idx
  on public.ai_chat_sessions (id, user_id);

create table if not exists public.ai_chat_messages (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null,
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  role text not null check (role in ('user', 'model')),
  body text not null check (char_length(body) between 1 and 8000),
  created_at timestamptz not null default now()
);

alter table public.ai_chat_messages
  drop constraint if exists ai_chat_messages_session_owner;
alter table public.ai_chat_messages
  add constraint ai_chat_messages_session_owner
  foreign key (session_id, user_id) references public.ai_chat_sessions (id, user_id)
  on delete cascade;

create index if not exists ai_chat_messages_user_created_idx
  on public.ai_chat_messages (user_id, created_at, id);

alter table public.ai_chat_sessions enable row level security;
alter table public.ai_chat_messages enable row level security;

-- Supabase default grants can include TRUNCATE, which RLS cannot restrict.
revoke all on table public.ai_chat_sessions from public, anon, authenticated;
revoke all on table public.ai_chat_messages from public, anon, authenticated;
grant select, insert, update, delete on public.ai_chat_sessions to authenticated;
grant select, insert, update, delete on public.ai_chat_messages to authenticated;

drop policy if exists ai_chat_sessions_own on public.ai_chat_sessions;
create policy ai_chat_sessions_own on public.ai_chat_sessions
  for all to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

drop policy if exists ai_chat_messages_own on public.ai_chat_messages;
create policy ai_chat_messages_own on public.ai_chat_messages
  for all to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

commit;
