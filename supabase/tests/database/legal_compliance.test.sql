begin;
-- --linked çalıştırmada CLI giriş rolü extensions şemasını kullanamıyor.
set local role postgres;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(19);

-- kurucu, öğrenci, yalnız kurucu
insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-0000000000e1', 'l-kurucu@test.com'),
  ('00000000-0000-0000-0000-0000000000e2', 'l-ogrenci@test.com'),
  ('00000000-0000-0000-0000-0000000000e3', 'l-yalniz@test.com');

create function pg_temp.login(uid text) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
$$;

set local role authenticated;
select pg_temp.login('00000000-0000-0000-0000-0000000000e1');
insert into medreses (id, name) values ('50000000-0000-0000-0000-000000000001', 'Uyum Medresesi');
select add_member_by_email('50000000-0000-0000-0000-000000000001', 'l-ogrenci@test.com');
insert into task_programs (medrese_id, start_date) values ('50000000-0000-0000-0000-000000000001', today_tr());
insert into posts (id, medrese_id, body)
  values ('50000000-0000-0000-0000-0000000000a1', '50000000-0000-0000-0000-000000000001', 'Kurucunun paylaşımı');

-- Açık rıza (KVKK m.6)
select pg_temp.login('00000000-0000-0000-0000-0000000000e2');
select throws_ok($$ insert into task_entries (medrese_id, task_id, day, value)
  values ('50000000-0000-0000-0000-000000000001', 'kitap', today_tr(), 10) $$,
  'P0001', 'task consent required', 'rıza olmadan girdi yazılamaz');
select pg_temp.login('00000000-0000-0000-0000-0000000000e1');
select throws_ok($$ insert into task_entries (medrese_id, student_id, task_id, day, value)
  values ('50000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-0000000000e2', 'kitap', today_tr(), 10) $$,
  'P0001', 'task consent required', 'hoca da rızası olmayan öğrenciye yazamaz');
select pg_temp.login('00000000-0000-0000-0000-0000000000e2');
select lives_ok($$ select give_task_consent() $$, 'öğrenci rıza verir');
select lives_ok($$ insert into task_entries (medrese_id, task_id, day, value)
  values ('50000000-0000-0000-0000-000000000001', 'kitap', today_tr(), 10) $$, 'rızayla girdi yazılır');
select pg_temp.login('00000000-0000-0000-0000-0000000000e1');
select is((select count(*)::int from task_consents), 0, 'başkasının rızası okunamaz');
select pg_temp.login('00000000-0000-0000-0000-0000000000e2');
select lives_ok($$ select revoke_task_consent() $$, 'öğrenci rızayı geri alır');
select is((select count(*)::int from task_entries where student_id = '00000000-0000-0000-0000-0000000000e2'),
  0, 'rıza geri alınınca girdiler silinir');

-- Şikayet (5651)
select lives_ok($$ select report_content('50000000-0000-0000-0000-0000000000a1', null, 'copyright', ' benim ') $$,
  'üye paylaşımı şikayet eder');
select throws_ok($$ select report_content('50000000-0000-0000-0000-0000000000a1', null, 'yok') $$,
  '23514', null, 'geçersiz neden reddedilir');
select is((select count(*)::int from reports), 0, 'istemci şikayetleri okuyamaz');
select pg_temp.login('00000000-0000-0000-0000-0000000000e3');
select throws_ok($$ select report_content('50000000-0000-0000-0000-0000000000a1', null, 'spam') $$,
  'P0001', 'not allowed', 'üye olmayan şikayet edemez');

-- Trafik bilgisi ve şikayet kaydı (sunucu tarafında)
set local role postgres;
select is((select content from reports), 'Kurucunun paylaşımı', 'şikayette içeriğin kopyası saklanır');
select is((select count(*)::int from content_logs where row_id = '50000000-0000-0000-0000-0000000000a1'),
  1, 'paylaşım trafik bilgisine yazılır');

-- Hesap silme ve kurucu devri
set local role authenticated;
select pg_temp.login('00000000-0000-0000-0000-0000000000e1');
select throws_ok($$ select delete_my_account() $$, 'P0001', 'transfer ownership first',
  'başka üyesi olan medresenin kurucusu hesabını silemez');
select throws_ok($$ select transfer_ownership('50000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-0000000000e3') $$,
  'P0001', 'not allowed', 'üye olmayana kurucu devredilemez');
select lives_ok($$ select transfer_ownership('50000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-0000000000e2') $$,
  'kurucu öğrenciye devreder');
select lives_ok($$ select delete_my_account() $$, 'devirden sonra hesap silinir');

set local role postgres;
select is((select count(*)::int from auth.users where id = '00000000-0000-0000-0000-0000000000e1'),
  0, 'kullanıcı silindi');
select is((select role::text from medrese_members where user_id = '00000000-0000-0000-0000-0000000000e2'),
  'owner', 'medrese yeni kurucuyla kalır');

select * from finish();
rollback;
