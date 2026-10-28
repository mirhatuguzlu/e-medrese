begin;
-- --linked çalıştırmada CLI giriş rolü extensions şemasını kullanamıyor.
set local role postgres;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(11);

-- hoca, öğrenci1, öğrenci2, yabancı
insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-0000000000b1', 'h-hoca@test.com'),
  ('00000000-0000-0000-0000-0000000000b2', 'h-ogrenci1@test.com'),
  ('00000000-0000-0000-0000-0000000000b3', 'h-ogrenci2@test.com'),
  ('00000000-0000-0000-0000-0000000000b4', 'h-yabanci@test.com');

create function pg_temp.login(uid text) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
$$;

set local role authenticated;
select pg_temp.login('00000000-0000-0000-0000-0000000000b1');
insert into medreses (id, name) values ('30000000-0000-0000-0000-000000000001', 'Sandık Medresesi');
select add_member_by_email('30000000-0000-0000-0000-000000000001', 'h-ogrenci1@test.com');
select add_member_by_email('30000000-0000-0000-0000-000000000001', 'h-ogrenci2@test.com');
-- 7 gün önce başlamış: biten dönem [bugün-7, bugün-1], sandık bugün açılır.
insert into task_programs (medrese_id, start_date)
  values ('30000000-0000-0000-0000-000000000001', today_tr() - 7);

-- Biten dönemin girdileri (öğrenci artık yazamaz; doğrudan eklenir).
set local role postgres;
insert into task_entries (medrese_id, student_id, task_id, day, item, value)
select '30000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-0000000000b2',
  'namaz', today_tr() - 7 + d, i, 1
from generate_series(0, 6) d, generate_series(0, 4) i;
insert into task_entries (medrese_id, student_id, task_id, day, item, value) values
  ('30000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-0000000000b2', 'cuz', today_tr() - 3, 0, 80),
  ('30000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-0000000000b2', 'kitap', today_tr() - 2, 0, 10);
set local role authenticated;

select pg_temp.login('00000000-0000-0000-0000-0000000000b2');
select throws_ok($$ insert into weekly_scores (medrese_id, student_id, period_start, total, details)
  values ('30000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-0000000000b2', today_tr() - 7, 999, '{}') $$,
  '42501', null, 'öğrenci puanını kendi yazamaz');
select finalize_task_scores('30000000-0000-0000-0000-000000000001');
select finalize_task_scores('30000000-0000-0000-0000-000000000001');
select is((select count(*)::int from weekly_scores
  where medrese_id = '30000000-0000-0000-0000-000000000001'), 2, 'biten dönem her öğrenci için bir kez kaydedilir');
select is((select total from weekly_scores where student_id = '00000000-0000-0000-0000-0000000000b2'),
  88.5714, '35 vakit (25) + 80 sayfa cüz (60, sınır) + 10 sayfa kitap (3,57)');
select is((select (details ->> 'cuz')::numeric from weekly_scores
  where student_id = '00000000-0000-0000-0000-0000000000b2'), 60.0000, 'görev dökümü kaydedilir');
select is((select total from weekly_scores where student_id = '00000000-0000-0000-0000-0000000000b3'),
  0.0000, 'işaretlemeyen öğrenci 0 puan');

select is((open_chest('30000000-0000-0000-0000-000000000001', today_tr() - 7)).total, 88.5714,
  'öğrenci sandığı açar');
select ok((select opened_at is not null from weekly_scores
  where student_id = '00000000-0000-0000-0000-0000000000b2'), 'açılma zamanı kaydedilir');
select throws_ok($$ select open_chest('30000000-0000-0000-0000-000000000001', today_tr()) $$,
  'chest not available', 'süren dönemin sandığı açılamaz');

select pg_temp.login('00000000-0000-0000-0000-0000000000b3');
select is((select count(*)::int from weekly_scores
  where medrese_id = '30000000-0000-0000-0000-000000000001'), 2, 'öğrenci sıralamayı görür');

select pg_temp.login('00000000-0000-0000-0000-0000000000b1');
select throws_ok($$ select open_chest('30000000-0000-0000-0000-000000000001', today_tr() - 7) $$,
  'not allowed', 'hoca sandık açamaz');

select pg_temp.login('00000000-0000-0000-0000-0000000000b4');
select throws_ok($$ select finalize_task_scores('30000000-0000-0000-0000-000000000001') $$,
  'not allowed', 'yabancı puan hesaplatamaz');

select * from finish();
rollback;
