begin;
insert into auth.users (id) values
 ('10000000-0000-4000-8000-000000000001'),
 ('10000000-0000-4000-8000-000000000002');
set local role authenticated;
select set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000001',true);
insert into public.ai_chat_sessions (id,user_id) values
 ('20000000-0000-4000-8000-000000000001',auth.uid());
insert into public.ai_chat_messages (id,session_id,user_id,role,body) values
 ('30000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001',auth.uid(),'user','Question A');
select test_assert.ok((select count(*)=1 from public.ai_chat_messages),'A reads own message') as check;
select test_assert.ok((select count(*)=1 from public.ai_chat_sessions),'A reads own session') as check;
update public.ai_chat_messages set body='Updated A' where id='30000000-0000-4000-8000-000000000001';
select test_assert.ok((select body='Updated A' from public.ai_chat_messages),'A updates own message') as check;
select test_assert.denied($$truncate public.ai_chat_messages$$,'authenticated cannot truncate messages') as check;
select test_assert.denied($$truncate public.ai_chat_sessions cascade$$,'authenticated cannot truncate sessions') as check;

select set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000002',true);
select test_assert.ok((select count(*)=0 from public.ai_chat_messages),'B cannot read A messages') as check;
select test_assert.ok((select count(*)=0 from public.ai_chat_sessions),'B cannot read A sessions') as check;
with changed as (update public.ai_chat_messages set body='Intrusion' returning id)
 select test_assert.ok((select count(*)=0 from changed),'B cannot update A messages') as check;
with removed as (delete from public.ai_chat_messages returning id)
 select test_assert.ok((select count(*)=0 from removed),'B cannot delete A messages') as check;
with removed as (delete from public.ai_chat_sessions returning id)
 select test_assert.ok((select count(*)=0 from removed),'B cannot delete A sessions') as check;
select test_assert.denied($$insert into public.ai_chat_messages (session_id,user_id,role,body) values ('20000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000001','user','Forged owner')$$,'B cannot forge A owner') as check;
select test_assert.denied($$insert into public.ai_chat_messages (session_id,user_id,role,body) values ('20000000-0000-4000-8000-000000000001',auth.uid(),'user','Foreign session')$$,'B own message cannot attach to A session','23503') as check;
insert into public.ai_chat_sessions (id,user_id) values
 ('20000000-0000-4000-8000-000000000002',auth.uid());
insert into public.ai_chat_messages (id,session_id,user_id,role,body) values
 ('30000000-0000-4000-8000-000000000002','20000000-0000-4000-8000-000000000002',auth.uid(),'model','Answer B');
select test_assert.ok((select count(*)=1 from public.ai_chat_messages),'B can write/read own message') as check;
select test_assert.denied($$insert into public.ai_chat_messages (session_id,user_id,role,body) values ('20000000-0000-4000-8000-000000000002',auth.uid(),'system','bad role')$$,'invalid role is rejected','23514') as check;
select test_assert.denied($$insert into public.ai_chat_messages (session_id,user_id,role,body) values ('20000000-0000-4000-8000-000000000002',auth.uid(),'user','')$$,'empty body is rejected','23514') as check;

select set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000001',true);
select test_assert.ok((select count(*)=1 and min(body)='Updated A' from public.ai_chat_messages),'return to A restores only A unchanged history') as check;
select test_assert.denied($$update public.ai_chat_messages set user_id='10000000-0000-4000-8000-000000000002'$$,'A cannot transfer message ownership') as check;
with removed as (delete from public.ai_chat_sessions returning id)
 select test_assert.ok((select count(*)=1 from removed),'A can delete own session') as check;
select test_assert.ok((select count(*)=0 from public.ai_chat_messages),'own session delete cascades only own messages') as check;
select set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000002',true);
select test_assert.ok((select count(*)=1 from public.ai_chat_messages),'A cascade does not delete B history') as check;
reset role;
set local role anon;
select test_assert.denied($$select * from public.ai_chat_messages$$,'anonymous cannot read messages') as check;
select test_assert.denied($$select * from public.ai_chat_sessions$$,'anonymous cannot read sessions') as check;
select test_assert.denied($$insert into public.ai_chat_sessions default values$$,'anonymous cannot create a session') as check;
select test_assert.denied($$truncate public.ai_chat_messages$$,'anonymous cannot truncate history') as check;
rollback;
