begin;
set local role postgres;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(10);

-- hoca, öğrenci1, öğrenci2
insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-0000000000c1', 'u-hoca@test.com'),
  ('00000000-0000-0000-0000-0000000000c2', 'u-ogrenci1@test.com'),
  ('00000000-0000-0000-0000-0000000000c3', 'u-ogrenci2@test.com');

create function pg_temp.login(uid text) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
$$;

set local role authenticated;
select pg_temp.login('00000000-0000-0000-0000-0000000000c1');
insert into medreses (id, name) values ('40000000-0000-0000-0000-000000000001', 'Uyum Medresesi');
select add_member_by_email('40000000-0000-0000-0000-000000000001', 'u-ogrenci1@test.com');
select add_member_by_email('40000000-0000-0000-0000-000000000001', 'u-ogrenci2@test.com');
insert into task_programs (medrese_id, start_date)
  values ('40000000-0000-0000-0000-000000000001', today_tr());

select lives_ok($$ select set_uyum('40000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-0000000000c2', 10, 'İlk') $$, 'hoca uyum puanı verir');
select lives_ok($$ select set_uyum('40000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-0000000000c2', 20, 'Bu hafta çok gayretliydin.') $$, 'hoca puanı değiştirir');
select is((select points from uyum_grades where student_id = '00000000-0000-0000-0000-0000000000c2'),
  20::numeric, 'son puan kalır');
select throws_ok($$ select set_uyum('40000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-0000000000c2', 26, '') $$, '23514', null, 'en fazla 25');
select throws_ok($$ select set_uyum('40000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-0000000000c1', 5, '') $$, 'not allowed', 'yalnızca öğrenciye');

select pg_temp.login('00000000-0000-0000-0000-0000000000c2');
select throws_ok($$ select set_uyum('40000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-0000000000c2', 25, '') $$, 'not allowed', 'öğrenci kendine puan veremez');
select is((select count(*)::int from uyum_grades), 0, 'öğrenci notu dönem içinde göremez');
-- Öğrencinin uyum için yazdığı girdi sayılmaz.
insert into task_entries (medrese_id, task_id, day, value)
  values ('40000000-0000-0000-0000-000000000001', 'uyum', today_tr(), 25);
insert into task_entries (medrese_id, task_id, day, value)
  values ('40000000-0000-0000-0000-000000000001', 'cevsen', today_tr(), 5);

-- Dönemi bitmiş gibi hesapla.
set local role postgres;
select is((select total from period_scores('40000000-0000-0000-0000-000000000001', today_tr())
  where student_id = '00000000-0000-0000-0000-0000000000c2'),
  95.0000, 'uyum 20 + cevşen 3 kez (75, sınır)');
select is((select note from period_scores('40000000-0000-0000-0000-000000000001', today_tr())
  where student_id = '00000000-0000-0000-0000-0000000000c2'),
  'Bu hafta çok gayretliydin.', 'not puanla gelir');
select is((select total from period_scores('40000000-0000-0000-0000-000000000001', today_tr())
  where student_id = '00000000-0000-0000-0000-0000000000c3'),
  0.0000, 'puan verilmeyen öğrenci 0');

select * from finish();
rollback;
