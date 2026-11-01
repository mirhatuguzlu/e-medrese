begin;
-- --linked çalıştırmada CLI giriş rolü extensions şemasını kullanamıyor.
set local role postgres;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(12);

-- hoca, öğrenci1, öğrenci2
insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-0000000000b1', 'b-hoca@test.com'),
  ('00000000-0000-0000-0000-0000000000b2', 'b-ogrenci1@test.com'),
  ('00000000-0000-0000-0000-0000000000b3', 'b-ogrenci2@test.com');

create function pg_temp.login(uid text) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
$$;

-- Giriş yapan kullanıcının [k] türündeki bildirim sayısı.
create function pg_temp.mine(k text) returns int language sql as $$
  select count(*)::int from notifications where kind = k
$$;

set local role authenticated;
select pg_temp.login('00000000-0000-0000-0000-0000000000b1');
insert into medreses (id, name) values ('30000000-0000-0000-0000-000000000001', 'Bildirim Medresesi');
select add_member_by_email('30000000-0000-0000-0000-000000000001', 'b-ogrenci1@test.com');
select add_member_by_email('30000000-0000-0000-0000-000000000001', 'b-ogrenci2@test.com');

-- Başlatma, durdurma, devam, bitiş
insert into task_programs (medrese_id, start_date)
values ('30000000-0000-0000-0000-000000000001', today_tr() - 7);
update task_programs set paused = true where medrese_id = '30000000-0000-0000-0000-000000000001';
update task_programs set paused = false where medrese_id = '30000000-0000-0000-0000-000000000001';

select pg_temp.login('00000000-0000-0000-0000-0000000000b2');
select is(pg_temp.mine('task_started'), 1, 'öğrenciye başlatma bildirimi');
select is(pg_temp.mine('task_paused'), 1, 'öğrenciye durdurma bildirimi');
select is(pg_temp.mine('task_resumed'), 1, 'öğrenciye devam bildirimi');

select pg_temp.login('00000000-0000-0000-0000-0000000000b1');
select is(pg_temp.mine('task_started'), 0, 'hocaya görev bildirimi gitmez');
insert into announcements (medrese_id, title) values ('30000000-0000-0000-0000-000000000001', 'Ders yok');
select is(pg_temp.mine('announcement'), 0, 'duyuruyu yazana bildirim gitmez');

select pg_temp.login('00000000-0000-0000-0000-0000000000b2');
select is(pg_temp.mine('announcement'), 1, 'öğrenciye duyuru bildirimi');
select is((select count(*)::int from notifications where user_id <> auth.uid()), 0,
  'başkasının bildirimi okunmaz');
update notifications set read_at = now();
select is((select count(*)::int from notifications where read_at is null), 0, 'okundu işaretlenir');
select throws_ok($$ insert into notifications (user_id, kind, title)
  values (auth.uid(), 'x', 'x') $$, '42501', null, 'bildirim elle yazılamaz');

-- Öğrenci1 bugün işaretledi, öğrenci2 işaretlemedi.
insert into task_entries (medrese_id, task_id, day, value)
values ('30000000-0000-0000-0000-000000000001', 'kitap', today_tr(), 10);

set local role postgres;
select notify_period_ready();
select notify_daily_reminder();
set local role authenticated;

select is(pg_temp.mine('period_ready'), 1, 'dönem bitince yıldız bildirimi');
select is(pg_temp.mine('reminder'), 0, 'işaretleyene hatırlatma gitmez');
select pg_temp.login('00000000-0000-0000-0000-0000000000b3');
select is(pg_temp.mine('reminder'), 1, 'işaretlemeyene hatırlatma gider');

select * from finish();
rollback;
