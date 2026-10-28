-- Görevler: hocanın başlattığı günden itibaren 7 günlük dönemlerle tekrar eden,
-- öğrencilerin kendi işaretlediği görevler.

-- Görev tanımları. Şimdilik sistem görevleri; ileride hocanın oluşturacağı
-- görevler de aynı yapıyla eklenir.
-- Puan = min(dönem toplamı, cap) * points / target
-- config.kind: 'checks' (günlük onay kutuları) | 'pages' (günlük sayfa sayısı)
create table public.task_definitions (
  id text primary key,
  title text not null,
  description text not null default '',
  config jsonb not null,
  sort int not null default 0
);

insert into public.task_definitions (id, title, description, sort, config) values
('namaz', 'Namaz', 'Her vakit için işaretle. Haftada 35 vakit = 25 puan.', 1,
 '{"kind":"checks","items":["Sabah","Öğle","İkindi","Akşam","Yatsı"],"target":35,"points":25,"cap":35}'),
('risale', 'Risale-i Nur okuma', 'Günde 3 sayfa. Haftada 21 sayfa = 25 puan, en fazla 63 sayfa (75 puan) sayılır.', 2,
 '{"kind":"pages","presets":[{"label":"Okudum (3 sayfa)","pages":3}],"target":21,"points":25,"cap":63}'),
('ders', 'Derse katılım', 'Salı ve Perşembe dersleri. Her ders 15 puan.', 3,
 '{"kind":"checks","items":["Derse katıldım"],"weekdays":[2,4],"target":2,"points":30,"cap":2}'),
('cuz', 'Kur''an-ı Kerim (cüz)', 'Haftada 1 cüz (20 sayfa) = 20 puan, her sayfa 1 puan. En fazla 3 cüz (60 puan) sayılır.', 4,
 '{"kind":"pages","presets":[{"label":"1 cüz","pages":20},{"label":"2 cüz","pages":40},{"label":"3 cüz","pages":60}],"target":20,"points":20,"cap":60}'),
('kitap', 'İslami kitap okuma', 'Günde 10 sayfa. Haftada 70 sayfa = 25 puan, en fazla 210 sayfa (75 puan) sayılır.', 5,
 '{"kind":"pages","presets":[],"target":70,"points":25,"cap":210}');

-- Medresenin görev programı: start_date'ten itibaren 7 günlük dönemler.
create table public.task_programs (
  medrese_id uuid primary key references public.medreses on delete cascade,
  start_date date not null,
  active boolean not null default true
);

-- Öğrencinin bir gün için girdisi. checks: işaretli her kutu bir satır (value 1);
-- pages: item 0, value = sayfa sayısı. İşaretlenmeyen = satır yok = 0 puan.
create table public.task_entries (
  medrese_id uuid not null references public.medreses on delete cascade,
  student_id uuid not null default auth.uid() references public.profiles on delete cascade,
  task_id text not null references public.task_definitions,
  day date not null,
  item int not null default 0 check (item between 0 and 9),
  value numeric not null check (value >= 0 and value <= 1000),
  primary key (medrese_id, student_id, task_id, day, item)
);

create index on public.task_entries (medrese_id, day);

-- shortcut: "bugün" Türkiye saatine göre; başka saat dilimindeki kullanıcılar
-- gün sınırında bir gün kayabilir. Gerekirse kullanıcının saat dilimini sakla.
create function public.today_tr() returns date
language sql stable as $$ select (now() at time zone 'Europe/Istanbul')::date $$;

-- Öğrenci yalnızca aktif programın içinde bulunduğu dönemin bugüne kadarki
-- günlerini yazabilir.
create function public.can_write_task_day(m uuid, d date) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.task_programs p
    where p.medrese_id = m
      and p.active
      and d <= public.today_tr()
      and d >= p.start_date
        + 7 * ((public.today_tr() - p.start_date) / 7)
  )
$$;

alter table public.task_definitions enable row level security;
alter table public.task_programs enable row level security;
alter table public.task_entries enable row level security;

create policy "task_definitions: everyone reads" on public.task_definitions
for select to authenticated using (true);

create policy "task_programs: members read" on public.task_programs
for select to authenticated using (public.my_role(medrese_id) is not null);
create policy "task_programs: staff starts" on public.task_programs
for insert to authenticated
with check (public.my_role(medrese_id) in ('owner', 'teacher'));
create policy "task_programs: staff updates" on public.task_programs
for update to authenticated
using (public.my_role(medrese_id) in ('owner', 'teacher'))
with check (public.my_role(medrese_id) in ('owner', 'teacher'));

create policy "task_entries: own or staff reads" on public.task_entries
for select to authenticated using (
  student_id = auth.uid()
  or public.my_role(medrese_id) in ('owner', 'teacher')
);
create policy "task_entries: student writes own" on public.task_entries
for insert to authenticated with check (
  student_id = auth.uid()
  and public.my_role(medrese_id) = 'student'
  and public.can_write_task_day(medrese_id, day)
);
create policy "task_entries: student updates own" on public.task_entries
for update to authenticated
using (student_id = auth.uid() and public.can_write_task_day(medrese_id, day))
with check (student_id = auth.uid() and public.can_write_task_day(medrese_id, day));
create policy "task_entries: student deletes own" on public.task_entries
for delete to authenticated
using (student_id = auth.uid() and public.can_write_task_day(medrese_id, day));

revoke update on public.task_entries, public.task_programs from anon, authenticated;
grant update (value) on public.task_entries to authenticated;
grant update (start_date, active) on public.task_programs to authenticated;
