begin;
insert into auth.users (id) values
 ('10000000-0000-4000-8000-000000000001'),
 ('10000000-0000-4000-8000-000000000002');
set local role authenticated;
select set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000001',true);
select test_assert.ok((select count(*)=5 from public.songs),'authenticated reads all five songs') as check;
insert into public.user_progress (user_id,song_id,is_completed,score) values (auth.uid(),'yesterday',true,50);
select test_assert.ok((select count(*)=1 and min(score)=50 from public.user_progress),'A persists completed score') as check;
select test_assert.denied($$truncate public.user_progress$$,'authenticated cannot truncate progress') as check;
select test_assert.denied($$truncate public.songs cascade$$,'authenticated cannot truncate catalogue') as check;
select test_assert.denied($$update public.songs set title='changed'$$,'authenticated cannot rewrite catalogue') as check;
select test_assert.denied($$insert into public.user_progress(user_id,song_id,is_completed,score) values(auth.uid(),'billie-jean',true,100)$$,'invalid completed score rejected','23514') as check;
select test_assert.denied($$insert into public.user_progress(user_id,song_id,is_completed,score) values(auth.uid(),'billie-jean',false,50)$$,'incomplete score cannot claim completion reward','23514') as check;
select test_assert.denied($$insert into public.user_progress(user_id,song_id,is_completed,score) values(auth.uid(),'unknown-song',false,0)$$,'unknown song cannot create progress','23503') as check;
select set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000002',true);
select test_assert.ok((select count(*)=0 from public.user_progress),'B cannot read A progress') as check;
with changed as (update public.user_progress set is_completed=false,score=0 returning song_id)
 select test_assert.ok((select count(*)=0 from changed),'B cannot overwrite A progress') as check;
with removed as (delete from public.user_progress returning song_id)
 select test_assert.ok((select count(*)=0 from removed),'B cannot delete A progress') as check;
select test_assert.denied($$insert into public.user_progress(user_id,song_id,is_completed,score) values('10000000-0000-4000-8000-000000000001','billie-jean',true,50)$$,'B cannot forge A owner') as check;
insert into public.user_progress (user_id,song_id,is_completed,score) values (auth.uid(),'billie-jean',true,50);
select test_assert.ok((select count(*)=1 and min(song_id)='billie-jean' from public.user_progress),'B has independent saved result') as check;
select set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000001',true);
select test_assert.ok((select count(*)=1 and min(song_id)='yesterday' and min(score)=50 from public.user_progress),'return to A restores original result') as check;
select test_assert.denied($$update public.user_progress set user_id='10000000-0000-4000-8000-000000000002'$$,'A cannot transfer result ownership') as check;
with removed as (delete from public.user_progress returning song_id)
 select test_assert.ok((select count(*)=1 from removed),'A can remove own result') as check;
select set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000002',true);
select test_assert.ok((select count(*)=1 from public.user_progress),'A delete preserves B result') as check;
reset role;
set local role anon;
select test_assert.ok((select count(*)=5 from public.songs),'anonymous catalogue read intentionally allowed') as check;
select test_assert.denied($$select * from public.user_progress$$,'anonymous progress read denied') as check;
select test_assert.denied($$insert into public.user_progress(user_id,song_id) values('10000000-0000-4000-8000-000000000001','yesterday')$$,'anonymous progress write denied') as check;
select test_assert.denied($$truncate public.user_progress$$,'anonymous truncate denied') as check;
rollback;
