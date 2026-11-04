-- Isolated test environment only. This file is never applied to a hosted project.
create role anon;
create role authenticated;
create schema auth;
create table auth.users (
  id uuid primary key,
  raw_user_meta_data jsonb not null default '{}'::jsonb
);
create function auth.uid() returns uuid language sql stable as
  $$select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid$$;
grant usage on schema auth, public to anon, authenticated;
grant execute on function auth.uid() to anon, authenticated;
-- Mimic broad legacy Supabase defaults, so migrations must revoke excess grants.
alter default privileges in schema public grant all on tables to anon, authenticated;

create schema test_assert;
grant usage on schema test_assert to anon, authenticated;
create function test_assert.ok(value boolean, label text) returns text
language plpgsql as $$begin
  if value is distinct from true then raise exception 'assertion failed: %', label; end if;
  return label;
end$$;
create function test_assert.denied(command text, label text, expected text default '42501')
returns text language plpgsql as $$declare actual text; begin
  begin
    execute command;
  exception when others then
    get stacked diagnostics actual = returned_sqlstate;
    if actual = expected then return label; end if;
    raise exception 'assertion failed: %, expected SQLSTATE %, received %', label, expected, actual;
  end;
  raise exception 'assertion failed: %, statement unexpectedly succeeded', label;
end$$;
