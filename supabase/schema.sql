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
