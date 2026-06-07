-- Диагностика телефонной регистрации: «юзер не появляется в auth.users».
-- Запускать в Supabase Dashboard → SQL Editor (там достаточно прав).
-- Скрипт ТОЛЬКО ЧИТАЕТ данные и ничего не меняет.
--
-- Важно понимать механику: при телефонной регистрации пользователь
-- создаётся самим Supabase Auth (GoTrue), а не Flutter-кодом. Создание
-- пользователя в auth.users может НЕ произойти по двум причинам:
--   1) AFTER INSERT триггер на auth.users падает с ошибкой и откатывает
--      всю транзакцию регистрации (этот скрипт проверяет триггеры/таблицу);
--   2) SMS-провайдер (Twilio) не смог отправить код — тогда GoTrue тоже
--      откатывает создание пользователя (это проверяется НЕ здесь, а в
--      Authentication → Logs и в настройках Phone-провайдера).

-- 1. Все триггеры на auth.users. Должен быть только on_auth_user_created.
--    Любой ЛИШНИЙ/чужой триггер — частая причина отката регистрации.
select tgname            as trigger_name,
       tgenabled         as enabled,           -- 'O' = enabled
       pg_get_triggerdef(oid) as definition
from pg_trigger
where tgrelid = 'auth.users'::regclass
  and not tgisinternal
order by tgname;

-- 2. Тело функции public.handle_new_user. Она должна быть SECURITY DEFINER
--    и НИКОГДА не бросать исключение (exception when others then return new).
select p.proname,
       p.prosecdef as security_definer,
       pg_get_functiondef(p.oid) as definition
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.proname = 'handle_new_user';

-- 3. Колонки public.profiles. display_name / age / musician_level ДОЛЖНЫ быть
--    nullable (is_nullable = YES). Если NOT NULL — триггер упадёт на вставке
--    профиля при регистрации и откатит создание auth-пользователя.
select column_name,
       data_type,
       is_nullable
from information_schema.columns
where table_schema = 'public'
  and table_name = 'profiles'
order by ordinal_position;

-- 4. CHECK-ограничения на public.profiles (значения age/musician_level/gender).
select con.conname,
       pg_get_constraintdef(con.oid) as definition
from pg_constraint con
join pg_class rel on rel.oid = con.conrelid
join pg_namespace nsp on nsp.oid = rel.relnamespace
where nsp.nspname = 'public'
  and rel.relname = 'profiles'
  and con.contype = 'c';

-- 5. Сколько вообще пользователей в auth.users и сколько по телефону.
select count(*)                                  as total_users,
       count(*) filter (where phone is not null) as phone_users,
       count(*) filter (where phone_confirmed_at is not null) as phone_confirmed,
       count(*) filter (where email is not null) as email_users
from auth.users;

-- 6. Последние 10 пользователей (видно, создаются ли вообще и подтверждён ли
--    телефон). Если строки появляются, но phone_confirmed_at пуст — SMS уходит,
--    но код не подтверждается.
select id,
       phone,
       email,
       phone_confirmed_at,
       email_confirmed_at,
       created_at
from auth.users
order by created_at desc
limit 10;

-- 7. «Осиротевшие» профили без auth-пользователя (следы прошлых откатов).
select pr.id, pr.display_name, pr.created_at
from public.profiles pr
left join auth.users u on u.id = pr.id
where u.id is null
order by pr.created_at desc;
