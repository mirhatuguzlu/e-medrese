begin;
create extension if not exists pgtap with schema extensions;
select plan(18);

-- hoca1 (sahip), hoca2, öğrenci1, öğrenci2, yabancı
insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-000000000001', 'hoca1@test.com'),
  ('00000000-0000-0000-0000-000000000002', 'hoca2@test.com'),
  ('00000000-0000-0000-0000-000000000003', 'ogrenci1@test.com'),
  ('00000000-0000-0000-0000-000000000004', 'ogrenci2@test.com'),
  ('00000000-0000-0000-0000-000000000005', 'yabanci@test.com');

create function pg_temp.login(uid text) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
$$;

set local role authenticated;

-- Medrese kurma
select pg_temp.login('00000000-0000-0000-0000-000000000001');
insert into medreses (id, name) values ('10000000-0000-0000-0000-000000000001', 'Test Medresesi');
select is(my_role('10000000-0000-0000-0000-000000000001'), 'owner', 'kuran kişi sahip olur');
select is((select count(*)::int from profiles where id = auth.uid()), 1, 'kayıtta profil oluşur');

-- E-postayla ekleme
select lives_ok($$ select add_member_by_email('10000000-0000-0000-0000-000000000001', 'HOCA2@test.com', 'teacher') $$,
  'sahip hoca ekler');
select lives_ok($$ select add_member_by_email('10000000-0000-0000-0000-000000000001', 'ogrenci1@test.com') $$,
  'sahip öğrenci ekler');
select throws_ok($$ select add_member_by_email('10000000-0000-0000-0000-000000000001', 'yok@test.com') $$,
  'user not found');

-- Davet koduyla katılma
reset role;
create temp table code as select invite_code from medreses;
grant select on code to authenticated;
set local role authenticated;
select pg_temp.login('00000000-0000-0000-0000-000000000004');
select is(join_medrese(lower((select invite_code from code))), '10000000-0000-0000-0000-000000000001'::uuid,
  'öğrenci kodla katılır (büyük/küçük harf fark etmez)');
select throws_ok($$ select join_medrese('YANLIS00') $$, 'invalid invite code');

-- Öğrenci yetkileri
select throws_ok($$ select add_member_by_email('10000000-0000-0000-0000-000000000001', 'yabanci@test.com') $$,
  'not allowed', 'öğrenci üye ekleyemez');
select throws_ok($$ insert into announcements (medrese_id, title) values ('10000000-0000-0000-0000-000000000001', 'x') $$,
  '42501', null, 'öğrenci duyuru yazamaz');
select lives_ok($$ insert into posts (medrese_id, body) values ('10000000-0000-0000-0000-000000000001', 'selam') $$,
  'öğrenci paylaşım yapar');
delete from medrese_members where user_id = '00000000-0000-0000-0000-000000000002';
select is((select count(*)::int from medrese_members where role = 'teacher'), 1, 'öğrenci hocayı çıkaramaz');
select throws_ok($$ update posts set medrese_id = gen_random_uuid() $$, '42501', null,
  'paylaşım başka medreseye taşınamaz');

-- Hoca yetkileri
select pg_temp.login('00000000-0000-0000-0000-000000000002');
select lives_ok($$ insert into announcements (medrese_id, title) values ('10000000-0000-0000-0000-000000000001', 'Ders iptal') $$,
  'hoca duyuru yazar');
select throws_ok($$ select add_member_by_email('10000000-0000-0000-0000-000000000001', 'yabanci@test.com', 'teacher') $$,
  'not allowed', 'hoca başka hoca ekleyemez');

-- Mesajlaşma ve çıkarılma
select pg_temp.login('00000000-0000-0000-0000-000000000003');
reset role;
create temp table conv (id uuid);
grant all on conv to authenticated;
set local role authenticated;
insert into conv select create_conversation('10000000-0000-0000-0000-000000000001',
  array['00000000-0000-0000-0000-000000000004'::uuid]);
insert into messages (conversation_id, body) select id, 'merhaba' from conv;

select pg_temp.login('00000000-0000-0000-0000-000000000002');
select is((select count(*)::int from messages), 0, 'sohbete dahil olmayan mesajları göremez');
delete from medrese_members where user_id = '00000000-0000-0000-0000-000000000004';

select pg_temp.login('00000000-0000-0000-0000-000000000004');
select is((select count(*)::int from messages), 0, 'çıkarılan öğrenci sohbeti artık göremez');

-- Yabancı
select pg_temp.login('00000000-0000-0000-0000-000000000005');
select is((select count(*)::int from medreses), 0, 'yabancı medreseyi göremez');
select throws_ok($$ select create_conversation('10000000-0000-0000-0000-000000000001',
  array['00000000-0000-0000-0000-000000000001'::uuid]) $$, 'not allowed', 'yabancı sohbet açamaz');

select * from finish();
rollback;
