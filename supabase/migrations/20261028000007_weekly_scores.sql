-- Haftalık puanlar: dönem bitince sunucuda hesaplanır ve kaydedilir.
-- Öğrenci dönem bittiği gün sandığı açar (opened_at); açmazsa puan yine kayıtlıdır.

create table public.weekly_scores (
  medrese_id uuid not null references public.medreses on delete cascade,
  student_id uuid not null references public.profiles on delete cascade,
  period_start date not null,
  total numeric not null,
  -- görev kimliği -> puan
  details jsonb not null,
  opened_at timestamptz,
  primary key (medrese_id, student_id, period_start)
);

create index on public.weekly_scores (medrese_id, period_start);

-- [p, p+6] dönemi için her öğrencinin puanı:
-- görev başına min(toplam, cap) * points / target.
create function public.period_scores(m uuid, p date)
returns table (student_id uuid, total numeric, details jsonb)
language sql stable security definer set search_path = '' as $$
  with students as (
    select user_id as student_id from public.medrese_members
    where medrese_id = m and role = 'student'
    union
    select e.student_id from public.task_entries e
    where e.medrese_id = m and e.day between p and p + 6
  ),
  sums as (
    select e.student_id, e.task_id, sum(e.value) as s
    from public.task_entries e
    where e.medrese_id = m and e.day between p and p + 6
    group by 1, 2
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
  select student_id, sum(pts), jsonb_object_agg(task_id, pts)
  from scored group by student_id
$$;

-- Aktif programın biten ama kaydedilmemiş dönemlerini kaydeder. Ayrı bir
-- zamanlayıcı yerine puanlar okunmadan önce çağrılır.
-- shortcut: yalnızca program aktifken çalışır; durdurulan programın son
-- dönemi, durdurmadan önce kimse bakmadıysa kaydedilmez.
create function public.finalize_task_scores(m uuid) returns void
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
    insert into public.weekly_scores (medrese_id, student_id, period_start, total, details)
    select m, s.student_id, p, s.total, s.details
    from public.period_scores(m, p) s
    on conflict do nothing;
  end loop;
end $$;

-- Öğrenci, dönemi biten günün ertesi (bugün = p + 7) sandığını açar.
create function public.open_chest(m uuid, p date) returns public.weekly_scores
language plpgsql security definer set search_path = '' as $$
declare
  row public.weekly_scores;
begin
  if public.my_role(m) is distinct from 'student' then
    raise exception 'not allowed';
  end if;
  if p + 7 <> public.today_tr() then
    raise exception 'chest not available';
  end if;
  perform public.finalize_task_scores(m);
  update public.weekly_scores set opened_at = coalesce(opened_at, now())
  where medrese_id = m and student_id = auth.uid() and period_start = p
  returning * into row;
  if row is null then
    raise exception 'chest not available';
  end if;
  return row;
end $$;

alter table public.weekly_scores enable row level security;

-- Sıralamayı öğrenciler de görür. Yazma yalnızca yukarıdaki fonksiyonlarla.
create policy "weekly_scores: members read" on public.weekly_scores
for select to authenticated using (public.my_role(medrese_id) is not null);

revoke execute on function
  public.period_scores(uuid, date),
  public.finalize_task_scores(uuid),
  public.open_chest(uuid, date)
from public, anon;
grant execute on function
  public.finalize_task_scores(uuid),
  public.open_chest(uuid, date)
to authenticated;
