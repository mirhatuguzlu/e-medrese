begin;
-- --linked çalıştırmada CLI giriş rolü extensions şemasını kullanamıyor.
set local role postgres;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(15);

-- hoca, öğrenci1, öğrenci2
insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-0000000000a1', 'g-hoca@test.com'),
  ('00000000-0000-0000-0000-0000000000a2', 'g-ogrenci1@test.com'),
  ('00000000-0000-0000-0000-0000000000a3', 'g-ogrenci2@test.com');

create function pg_temp.login(uid text) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
$$;

set local role authenticated;
select pg_temp.login('00000000-0000-0000-0000-0000000000a1');
insert into medreses (id, name) values ('20000000-0000-0000-0000-000000000001', 'Görev Medresesi');
select add_member_by_email('20000000-0000-0000-0000-000000000001', 'g-ogrenci1@test.com');
select add_member_by_email('20000000-0000-0000-0000-000000000001', 'g-ogrenci2@test.com');

select is((select count(*)::int from task_definitions), 5, 'görev tanımları okunur');

-- Program başlamadan
select pg_temp.login('00000000-0000-0000-0000-0000000000a2');
select throws_ok($$ insert into task_entries (medrese_id, task_id, day, value)
  values ('20000000-0000-0000-0000-000000000001', 'kitap', today_tr(), 10) $$,
  '42501', null, 'program başlamadan yazılamaz');
select throws_ok($$ insert into task_programs (medrese_id, start_date)
  values ('20000000-0000-0000-0000-000000000001', today_tr()) $$,
  '42501', null, 'öğrenci programı başlatamaz');

-- Hoca 8 gün önce başlatmış gibi: içinde bulunulan dönem dün başladı.
select pg_temp.login('00000000-0000-0000-0000-0000000000a1');
select lives_ok($$ insert into task_programs (medrese_id, start_date, active)
  values ('20000000-0000-0000-0000-000000000001', today_tr(), false)
  on conflict (medrese_id) do update set medrese_id = excluded.medrese_id,
  start_date = excluded.start_date, active = excluded.active $$, 'hoca upsert ile programı kaydeder');
select lives_ok($$ update task_programs set start_date = today_tr() - 8, active = true
  where medrese_id = '20000000-0000-0000-0000-000000000001' $$, 'hoca programı başlatır');
select throws_ok($$ insert into task_entries (medrese_id, task_id, day, value)
  values ('20000000-0000-0000-0000-000000000001', 'kitap', today_tr(), 10) $$,
  '42501', null, 'hoca görev işaretleyemez');

select pg_temp.login('00000000-0000-0000-0000-0000000000a2');
select lives_ok($$ insert into task_entries (medrese_id, task_id, day, value)
  values ('20000000-0000-0000-0000-000000000001', 'kitap', today_tr(), 10) $$, 'öğrenci bugünü işaretler');
select lives_ok($$ insert into task_entries (medrese_id, task_id, day, item, value)
  values ('20000000-0000-0000-0000-000000000001', 'namaz', today_tr() - 1, 2, 1) $$,
  'öğrenci dönemin geçmiş gününü işaretler');
insert into task_entries (medrese_id, student_id, task_id, day, item, value)
  values ('20000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-0000000000a2', 'kitap', today_tr(), 0, 15)
  on conflict (medrese_id, student_id, task_id, day, item) do update
  set medrese_id = excluded.medrese_id, student_id = excluded.student_id, task_id = excluded.task_id,
      day = excluded.day, item = excluded.item, value = excluded.value;
select is((select value::int from task_entries where task_id = 'kitap'), 15, 'öğrenci upsert ile günceller');
update task_entries set value = 10 where task_id = 'kitap';
select throws_ok($$ insert into task_entries (medrese_id, task_id, day, value)
  values ('20000000-0000-0000-0000-000000000001', 'kitap', today_tr() - 2, 10) $$,
  '42501', null, 'önceki dönem değiştirilemez');
select throws_ok($$ insert into task_entries (medrese_id, task_id, day, value)
  values ('20000000-0000-0000-0000-000000000001', 'kitap', today_tr() + 1, 10) $$,
  '42501', null, 'gelecek gün işaretlenemez');

select pg_temp.login('00000000-0000-0000-0000-0000000000a3');
select is((select count(*)::int from task_entries), 0, 'öğrenci başkasının girdisini göremez');

select pg_temp.login('00000000-0000-0000-0000-0000000000a1');
select is((select count(*)::int from task_entries
  where medrese_id = '20000000-0000-0000-0000-000000000001'), 2, 'hoca öğrencilerin girdilerini görür');

-- Program durdurulunca
update task_programs set active = false where medrese_id = '20000000-0000-0000-0000-000000000001';
select pg_temp.login('00000000-0000-0000-0000-0000000000a2');
update task_entries set value = 20 where task_id = 'kitap';
select is((select value::int from task_entries where task_id = 'kitap'), 10, 'durdurulan programda değiştirilemez');
select throws_ok($$ insert into task_entries (medrese_id, task_id, day, value)
  values ('20000000-0000-0000-0000-000000000001', 'risale', today_tr(), 3) $$,
  '42501', null, 'durdurulan programa yazılamaz');

select * from finish();
rollback;
