begin;
-- --linked çalıştırmada CLI giriş rolü extensions şemasını kullanamıyor.
set local role postgres;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(6);

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-0000000000f1', 'r-kurucu@test.com'),
  ('00000000-0000-0000-0000-0000000000f2', 'r-ogrenci@test.com');

create function pg_temp.login(uid text) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
$$;

set local role authenticated;
select pg_temp.login('00000000-0000-0000-0000-0000000000f1');
insert into medreses (id, name) values ('60000000-0000-0000-0000-000000000001', 'Ödül Medresesi');
select add_member_by_email('60000000-0000-0000-0000-000000000001', 'r-ogrenci@test.com');

select lives_ok($$ insert into rewards (id, medrese_id, title, points)
  values ('60000000-0000-0000-0000-0000000000a1', '60000000-0000-0000-0000-000000000001', 'Kitap', 1000) $$,
  'hoca ödül ekler');
select throws_ok($$ insert into reward_goals (medrese_id, reward_id, deadline)
  values ('60000000-0000-0000-0000-000000000001', '60000000-0000-0000-0000-0000000000a1', '2026-12-31') $$,
  '42501', null, 'hoca hedef seçemez');

select pg_temp.login('00000000-0000-0000-0000-0000000000f2');
select throws_ok($$ insert into rewards (medrese_id, title, points)
  values ('60000000-0000-0000-0000-000000000001', 'Benim ödülüm', 1) $$,
  '42501', null, 'öğrenci ödül ekleyemez');
select lives_ok($$ insert into reward_goals (medrese_id, reward_id, deadline)
  values ('60000000-0000-0000-0000-000000000001', '60000000-0000-0000-0000-0000000000a1', '2026-12-31') $$,
  'öğrenci ödülü hedef seçer');

select pg_temp.login('00000000-0000-0000-0000-0000000000f1');
select is((select count(*)::int from reward_goals), 0, 'hoca öğrencinin hedefini görmez');

select pg_temp.login('00000000-0000-0000-0000-0000000000f2');
select give_task_consent();
select revoke_task_consent();
select is((select count(*)::int from reward_goals), 0, 'rıza geri alınınca hedef silinir');

select * from finish();
rollback;
