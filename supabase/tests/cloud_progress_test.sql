begin;
insert into auth.users (id) values
 ('10000000-0000-4000-8000-000000000001'),
 ('10000000-0000-4000-8000-000000000002');
create function test_assert.book(owner uuid, evidence boolean default false) returns jsonb language sql as $$
 select jsonb_build_object('user_id',owner::text,
 'competencies',case when evidence then '{"pitch":{"status":"provisional","interval_step":0,"due_at":null,"provisional_at":null,"stability":[]}}'::jsonb else '{}'::jsonb end,
 'returns','[]'::jsonb,
 'attempts',case when evidence then '[{"competency_id":"pitch","session_id":"test","item_signature":"pitch-1","error_tag":"","is_correct":true,"response_ms":20,"hints_used":0,"replays":0,"tonality":"C","critical":false,"cold_review":false,"transfer":false,"created_at":"2026-11-05T00:00:00Z"}]'::jsonb else '[]'::jsonb end)
$$;
grant execute on function test_assert.book(uuid,boolean) to authenticated;
set local role authenticated;
select set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000001',true);
select test_assert.ok(public.save_practice_book(auth.uid(),0,'40000000-0000-4000-8000-000000000001',test_assert.book(auth.uid()))=1,'initial save creates revision one') as check;
select test_assert.ok((select count(*)=1 from public.practice_books),'owner can read book') as check;
select test_assert.ok(public.save_practice_book(auth.uid(),0,'40000000-0000-4000-8000-000000000001',test_assert.book(auth.uid()))=1,'identical retry is idempotent') as check;
select test_assert.ok((select count(*)=1 from public.practice_book_versions),'retry does not create another history row') as check;
select test_assert.denied($$select public.save_practice_book(auth.uid(),0,'40000000-0000-4000-8000-000000000001',test_assert.book(auth.uid(),true))$$,'write ID cannot acknowledge different content','22023') as check;
select test_assert.denied($$select public.save_practice_book(auth.uid(),0,'40000000-0000-4000-8000-000000000002',test_assert.book(auth.uid(),true))$$,'stale revision loses CAS without overwriting','PT409') as check;
select test_assert.ok(public.save_practice_book(auth.uid(),1,'40000000-0000-4000-8000-000000000002',test_assert.book(auth.uid(),true))=2,'new evidence commits as revision two') as check;
select test_assert.ok((select count(*)=1 from public.practice_attempts),'attempt rows saved with book') as check;
select test_assert.ok((select count(*)=1 from public.practice_competencies),'competency rows saved with book') as check;
select test_assert.ok((select count(*)=2 from public.practice_book_versions),'previous JSON revisions retained') as check;
select test_assert.denied($$select public.save_practice_book(auth.uid(),2,'40000000-0000-4000-8000-000000000003',jsonb_set(test_assert.book(auth.uid()),'{attempts}','[{"competency_id":"invalid"}]'))$$,'invalid derived row rolls back transaction','23502') as check;
select test_assert.ok((select revision=2 and book=test_assert.book(auth.uid(),true) from public.practice_books),'failed save preserves prior book and revision') as check;
select test_assert.ok((select count(*)=1 from public.practice_attempts),'failed save preserves prior attempts') as check;
select test_assert.ok((select count(*)=1 from public.practice_competencies),'failed save preserves prior competencies') as check;
select test_assert.ok((select count(*)=2 from public.practice_book_versions),'failed save does not create fake version') as check;
select test_assert.denied($$select public.save_practice_book('10000000-0000-4000-8000-000000000002',0,'40000000-0000-4000-8000-000000000004',test_assert.book('10000000-0000-4000-8000-000000000002'))$$,'A cannot save B book') as check;
select test_assert.denied($$select public.save_practice_book(auth.uid(),2,'40000000-0000-4000-8000-000000000004',test_assert.book('10000000-0000-4000-8000-000000000002'))$$,'book owner must match RPC owner','22023') as check;
select test_assert.denied($$update public.practice_books set revision=99$$,'direct book update denied') as check;
select test_assert.denied($$delete from public.practice_attempts$$,'direct attempts delete denied') as check;
select test_assert.denied($$delete from public.practice_competencies$$,'direct competency delete denied') as check;
select test_assert.denied($$delete from public.practice_returns$$,'direct returns delete denied') as check;
select test_assert.denied($$delete from public.practice_book_versions$$,'direct history delete denied') as check;
select test_assert.denied($$truncate public.practice_books cascade$$,'direct truncate denied') as check;
select set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000002',true);
select test_assert.ok((select count(*)=0 from public.practice_books),'B cannot read A book') as check;
select test_assert.ok((select count(*)=0 from public.practice_attempts),'B cannot read A attempts') as check;
select test_assert.ok((select count(*)=0 from public.practice_competencies),'B cannot read A competencies') as check;
select test_assert.ok((select count(*)=0 from public.practice_book_versions),'B cannot read A history') as check;
select test_assert.ok(public.save_practice_book(auth.uid(),0,'40000000-0000-4000-8000-000000000005',test_assert.book(auth.uid()))=1,'B creates an independent book') as check;
select set_config('request.jwt.claim.sub','',true);
select test_assert.denied($$select public.save_practice_book('10000000-0000-4000-8000-000000000002',1,'40000000-0000-4000-8000-000000000006',test_assert.book('10000000-0000-4000-8000-000000000002'))$$,'missing JWT owner denied') as check;
reset role;
set local role anon;
select test_assert.denied($$select * from public.practice_books$$,'anonymous read denied') as check;
select test_assert.denied($$select public.save_practice_book('10000000-0000-4000-8000-000000000002',1,'40000000-0000-4000-8000-000000000006','{}')$$,'anonymous RPC denied') as check;
rollback;
