-- Application revision conflicts must return HTTP409, not retryable serialization_failure.
-- Supersedes only the RPC definition; migration001 is immutable deployment history.
-- https://supabase.com/kb/troubleshooting/high-cpu-and-infinite-transaction-retries-when-using-custom-error-codes-in-rpc-functions-77326b
begin;

create or replace function public.save_practice_book(
  p_user_id uuid,
  p_expected_revision bigint,
  p_write_id uuid,
  p_book jsonb
) returns bigint
language plpgsql
security definer
set search_path = ''
as $function$
declare
  current_revision bigint;
  current_book jsonb;
  current_write_id uuid;
begin
  if auth.uid() is null or auth.uid() <> p_user_id or p_user_id is null then
    raise exception 'Practice book owner does not match the authenticated user'
      using errcode = '42501';
  end if;
  if p_expected_revision is null or p_expected_revision < 0 or p_write_id is null
     or jsonb_typeof(p_book) is distinct from 'object'
     or p_book ->> 'user_id' is distinct from p_user_id::text
     or jsonb_typeof(p_book -> 'competencies') is distinct from 'object'
     or jsonb_typeof(p_book -> 'attempts') is distinct from 'array'
     or jsonb_typeof(p_book -> 'returns') is distinct from 'array' then
    raise exception 'Invalid owned practice book' using errcode = '22023';
  end if;

  -- Creating the initial row and locking it also serializes concurrent first saves.
  -- Everything, including this placeholder, rolls back on any later error.
  insert into public.practice_books (user_id, book, revision)
  values (p_user_id, jsonb_build_object('user_id', p_user_id::text,
    'competencies', '{}'::jsonb, 'attempts', '[]'::jsonb, 'returns', '[]'::jsonb), 0)
  on conflict (user_id) do nothing;
  select revision, book, last_write_id
    into current_revision, current_book, current_write_id
    from public.practice_books where user_id = p_user_id for update;

  if current_write_id = p_write_id then
    if current_book <> p_book then
      raise exception 'A write id cannot be reused for different data'
        using errcode = '22023';
    end if;
    return current_revision;
  end if;
  if current_revision <> p_expected_revision then
    raise exception 'Practice book revision conflict'
      using errcode = 'PT409', detail = current_revision::text;
  end if;

  -- Retain the prior JSON even after an explicit user conflict/import choice.
  insert into public.practice_book_versions (user_id, revision, book, write_id)
  values (p_user_id, current_revision, current_book, current_write_id);

  delete from public.practice_attempts where user_id = p_user_id;
  insert into public.practice_attempts (
    user_id, competency_id, session_id, item_signature, error_tag, is_correct,
    response_ms, hints_used, replays, tonality, critical, cold_review, transfer,
    created_at
  ) select p_user_id, item ->> 'competency_id', item ->> 'session_id',
      item ->> 'item_signature', coalesce(item ->> 'error_tag', ''),
      (item ->> 'is_correct')::boolean, (item ->> 'response_ms')::integer,
      (item ->> 'hints_used')::integer, (item ->> 'replays')::integer,
      item ->> 'tonality', (item ->> 'critical')::boolean,
      (item ->> 'cold_review')::boolean, (item ->> 'transfer')::boolean,
      (item ->> 'created_at')::timestamptz
    from jsonb_array_elements(p_book -> 'attempts') as entry(item);

  delete from public.practice_competencies where user_id = p_user_id;
  insert into public.practice_competencies (
    user_id, competency_id, status, interval_step, due_at, provisional_at,
    stability, updated_at
  ) select p_user_id, item.key, item.value ->> 'status',
      (item.value ->> 'interval_step')::integer,
      (item.value ->> 'due_at')::timestamptz,
      (item.value ->> 'provisional_at')::timestamptz,
      item.value -> 'stability', now()
    from jsonb_each(p_book -> 'competencies') as item;

  delete from public.practice_returns where user_id = p_user_id;
  insert into public.practice_returns (user_id, tag, due_at)
    select p_user_id, item ->> 'tag', (item ->> 'due_at')::timestamptz
      from jsonb_array_elements(p_book -> 'returns') as entry(item);

  update public.practice_books set book = p_book, revision = current_revision + 1,
    last_write_id = p_write_id, updated_at = now() where user_id = p_user_id;
  return current_revision + 1;
end;
$function$;
revoke all on function public.save_practice_book(uuid, bigint, uuid, jsonb)
  from public, anon;
grant execute on function public.save_practice_book(uuid, bigint, uuid, jsonb)
  to authenticated;

commit;
