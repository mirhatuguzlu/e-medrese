-- Cevşen: haftada kaç kez bitirildiği (dönemin ilk gününe tek girdi).
-- Uyum: hocanın her dönem öğrenciye verdiği en fazla 25 puan ve notu;
-- öğrenci sandıkta görür.

insert into public.task_definitions (id, title, description, sort, config) values
('cevsen', 'Cevşen okuma', 'Haftada kaç kez bitirdiğini işaretle. 1 kez = 25 puan, en fazla 3 kez (75 puan) sayılır.', 6,
 '{"kind":"weekly","target":1,"points":25,"cap":3}'),
('uyum', 'Uyum', 'Hocanın haftalık değerlendirmesi. En fazla 25 puan.', 7,
 '{"kind":"teacher","target":25,"points":25,"cap":25}');

-- Medresenin süren döneminin ilk günü; program aktif değilse null.
create function public.current_period_start(m uuid) returns date
language sql stable security definer set search_path = '' as $$
  select p.start_date + 7 * ((public.today_tr() - p.start_date) / 7)
  from public.task_programs p
  where p.medrese_id = m and p.active and p.start_date <= public.today_tr()
$$;

create table public.uyum_grades (
  medrese_id uuid not null references public.medreses on delete cascade,
  student_id uuid not null references public.profiles on delete cascade,
  period_start date not null,
  points numeric not null check (points between 0 and 25),
  note text not null default '' check (length(note) <= 1000),
  primary key (medrese_id, student_id, period_start)
);

alter table public.uyum_grades enable row level security;

-- Öğrenci notu dönem bitince sandıkta görür (weekly_scores.note).
create policy "uyum_grades: staff reads" on public.uyum_grades
for select to authenticated
using (public.my_role(medrese_id) in ('owner', 'teacher'));

-- Hoca yalnızca süren dönem için, medresenin öğrencisine puan verir.
create function public.set_uyum(m uuid, s uuid, points numeric, note text)
returns void
language plpgsql security definer set search_path = '' as $$
declare
  p date := public.current_period_start(m);
begin
  if public.my_role(m) is null or public.my_role(m) not in ('owner', 'teacher')
    or p is null
    or not exists (
      select 1 from public.medrese_members
      where medrese_id = m and user_id = s and role = 'student'
    ) then
    raise exception 'not allowed';
  end if;
  insert into public.uyum_grades (medrese_id, student_id, period_start, points, note)
  values (m, s, p, points, coalesce(note, ''))
  on conflict (medrese_id, student_id, period_start)
  do update set points = excluded.points, note = excluded.note;
end $$;

-- Öğrenci 'teacher' türü görevlere (uyum) girdi yazamaz.
create function public.student_writable_task(t text) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.task_definitions
    where id = t and config ->> 'kind' <> 'teacher'
  )
$$;

drop policy "task_entries: student writes own" on public.task_entries;
create policy "task_entries: student writes own" on public.task_entries
for insert to authenticated with check (
  student_id = auth.uid()
  and public.my_role(medrese_id) = 'student'
  and public.can_write_task_day(medrese_id, day)
  and public.student_writable_task(task_id)
);
drop policy "task_entries: student updates own" on public.task_entries;
create policy "task_entries: student updates own" on public.task_entries
for update to authenticated
using (student_id = auth.uid() and public.can_write_task_day(medrese_id, day))
with check (
  student_id = auth.uid()
  and public.my_role(medrese_id) = 'student'
  and public.can_write_task_day(medrese_id, day)
  and public.student_writable_task(task_id)
);

alter table public.weekly_scores add column note text not null default '';

-- Uyum puanı ve notu da hesaplanır. Öğrencinin 'teacher' türü görevlere
-- yazdığı girdiler sayılmaz.
drop function public.period_scores(uuid, date);
create function public.period_scores(m uuid, p date)
returns table (student_id uuid, total numeric, details jsonb, note text)
language sql stable security definer set search_path = '' as $$
  with students as (
    select user_id as student_id from public.medrese_members
    where medrese_id = m and role = 'student'
    union
    select e.student_id from public.task_entries e
    where e.medrese_id = m and e.day between p and p + 6
    union
    select g.student_id from public.uyum_grades g
    where g.medrese_id = m and g.period_start = p
  ),
  sums as (
    select e.student_id, e.task_id, sum(e.value) as s
    from public.task_entries e
    join public.task_definitions d on d.id = e.task_id
    where e.medrese_id = m and e.day between p and p + 6
      and d.config ->> 'kind' <> 'teacher'
    group by 1, 2
    union all
    select g.student_id, 'uyum', g.points
    from public.uyum_grades g
    where g.medrese_id = m and g.period_start = p
  ),
  scored as (
    select st.student_id, d.id as task_id,
      round(
        least(coalesce(su.s, 0), (d.config ->> 'cap')::numeric)
          * (d.config ->> 'points')::numeric
          / (d.config ->> 'target')::numeric,
        4
      ) as pts
    from students st
    cross join public.task_definitions d
    left join sums su on su.student_id = st.student_id and su.task_id = d.id
  )
  select sc.student_id, sum(sc.pts), jsonb_object_agg(sc.task_id, sc.pts),
    coalesce(g.note, '')
  from scored sc
  left join public.uyum_grades g
    on g.medrese_id = m and g.period_start = p and g.student_id = sc.student_id
  group by sc.student_id, g.note
$$;

create or replace function public.finalize_task_scores(m uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare
  prog public.task_programs;
  p date;
begin
  if public.my_role(m) is null then
    raise exception 'not allowed';
  end if;
  select * into prog from public.task_programs where medrese_id = m and active;
  if not found then
    return;
  end if;
  for p in
    select prog.start_date + 7 * i
    from generate_series(0, (public.today_tr() - prog.start_date) / 7 - 1) i
  loop
    insert into public.weekly_scores (medrese_id, student_id, period_start, total, details, note)
    select m, s.student_id, p, s.total, s.details, s.note
    from public.period_scores(m, p) s
    on conflict do nothing;
  end loop;
end $$;

revoke execute on function
  public.period_scores(uuid, date),
  public.current_period_start(uuid),
  public.set_uyum(uuid, uuid, numeric, text)
from public, anon;
grant execute on function public.set_uyum(uuid, uuid, numeric, text) to authenticated;
