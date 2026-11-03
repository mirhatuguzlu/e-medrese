begin;
-- --linked çalıştırmada CLI giriş rolü extensions şemasını kullanamıyor.
set local role postgres;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(16);

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
select is((select count(*)::int from notifications where kind = 'reward'), 1,
  'öğrenciye yeni ödül bildirimi');
select throws_ok($$ insert into rewards (medrese_id, title, points)
  values ('60000000-0000-0000-0000-000000000001', 'Benim ödülüm', 1) $$,
  '42501', null, 'öğrenci ödül ekleyemez');
select lives_ok($$ insert into reward_goals (medrese_id, reward_id, deadline)
  values ('60000000-0000-0000-0000-000000000001', '60000000-0000-0000-0000-0000000000a1', '2026-12-31') $$,
  'öğrenci ödülü hedef seçer');
select throws_ok($$ select request_reward('60000000-0000-0000-0000-0000000000a1') $$,
  'P0001', 'not enough points', 'puana ulaşmadan istenemez');

select pg_temp.login('00000000-0000-0000-0000-0000000000f1');
select is((select count(*)::int from reward_goals), 0, 'hoca öğrencinin hedefini görmez');
select is((select count(*)::int from reward_claims), 0, 'istek yokken hoca teslim edecek bir şey görmez');

-- Biten haftalardan 1200 puan.
set local role postgres;
insert into weekly_scores (medrese_id, student_id, period_start, total, details)
values ('60000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-0000000000f2', '2026-10-01', 1200, '{}');
set local role authenticated;

select pg_temp.login('00000000-0000-0000-0000-0000000000f2');
select lives_ok($$ select request_reward('60000000-0000-0000-0000-0000000000a1') $$,
  'puana ulaşınca ödül istenir');
select throws_ok($$ select request_reward('60000000-0000-0000-0000-0000000000a1') $$,
  'P0001', 'already requested', 'bekleyen ödül yeniden istenmez');
select throws_ok($$ select deliver_reward((select id from reward_claims limit 1)) $$,
  'P0001', 'not staff of this medrese', 'öğrenci teslim işaretleyemez');

select pg_temp.login('00000000-0000-0000-0000-0000000000f1');
select is((select count(*)::int from notifications where kind = 'reward_request'), 1,
  'hocaya ödül isteği bildirimi');
select lives_ok($$ select deliver_reward((select id from reward_claims limit 1)) $$,
  'hoca istenen ödülü teslim eder');
select throws_ok($$ select deliver_reward((select id from reward_claims limit 1)) $$,
  'P0001', 'already delivered', 'iki kez teslim edilmez');

select pg_temp.login('00000000-0000-0000-0000-0000000000f2');
select is((select count(*)::int from reward_goals), 0, 'teslim edilen ödül hedeften kalkar');
-- 1200 - 1000 = 200 kaldı.
select throws_ok($$ select request_reward('60000000-0000-0000-0000-0000000000a1') $$,
  'P0001', 'not enough points', 'teslim edilen ödülün puanı düşülür');

select * from finish();
rollback;
