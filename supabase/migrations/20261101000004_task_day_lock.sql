-- Geçmiş günler kilitli: öğrenci yalnızca bugünü, gece 04:00'e kadar dünü
-- de yazabilir. Haftalık görev dönemin ilk gününe yazıldığı için dönem
-- boyunca açık kalır. Hocalar süren dönemin geçmiş günlerini düzeltebilir.

-- shortcut: dün, yalnızca aynı dönemdeyse açıktır (can_write_task_day);
-- dönemin son günü gece yarısında kapanır, çünkü puanlar ertesi gün kaydedilir.
create function public.can_write_task_entry(m uuid, t text, d date) returns boolean
language sql stable security definer set search_path = '' as $$
  select public.can_write_task_day(m, d)
    and (
      d >= ((now() at time zone 'Europe/Istanbul') - interval '4 hours')::date
      or exists (
        select 1 from public.task_definitions
        where id = t and config ->> 'kind' = 'weekly'
      )
    )
$$;

-- Hoca: aktif programın süren döneminde bugüne kadarki günler (durdurulmuş
-- olsa da).
create function public.can_staff_write_task_day(m uuid, s uuid, d date) returns boolean
language sql stable security definer set search_path = '' as $$
  select public.my_role(m) in ('owner', 'teacher')
    and exists (
      select 1 from public.medrese_members
      where medrese_id = m and user_id = s and role = 'student'
    )
    and d <= public.today_tr()
    and d >= public.current_period_start(m)
$$;

drop policy "task_entries: student writes own" on public.task_entries;
create policy "task_entries: student writes own" on public.task_entries
for insert to authenticated with check (
  student_id = auth.uid()
  and public.my_role(medrese_id) = 'student'
  and public.can_write_task_entry(medrese_id, task_id, day)
  and public.student_writable_task(task_id)
);
drop policy "task_entries: student updates own" on public.task_entries;
create policy "task_entries: student updates own" on public.task_entries
for update to authenticated
using (student_id = auth.uid() and public.can_write_task_entry(medrese_id, task_id, day))
with check (
  student_id = auth.uid()
  and public.my_role(medrese_id) = 'student'
  and public.can_write_task_entry(medrese_id, task_id, day)
  and public.student_writable_task(task_id)
);
drop policy "task_entries: student deletes own" on public.task_entries;
create policy "task_entries: student deletes own" on public.task_entries
for delete to authenticated
using (student_id = auth.uid() and public.can_write_task_entry(medrese_id, task_id, day));

create policy "task_entries: staff writes" on public.task_entries
for insert to authenticated with check (
  public.can_staff_write_task_day(medrese_id, student_id, day)
  and public.student_writable_task(task_id)
);
create policy "task_entries: staff updates" on public.task_entries
for update to authenticated
using (public.can_staff_write_task_day(medrese_id, student_id, day))
with check (
  public.can_staff_write_task_day(medrese_id, student_id, day)
  and public.student_writable_task(task_id)
);
create policy "task_entries: staff deletes" on public.task_entries
for delete to authenticated
using (public.can_staff_write_task_day(medrese_id, student_id, day));
