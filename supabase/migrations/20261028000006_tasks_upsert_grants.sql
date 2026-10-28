-- Upsert (ON CONFLICT DO UPDATE) gönderilen bütün kolonları günceller; kolon
-- izni yalnızca value/start_date'te olunca reddediliyordu. Yetkiyi RLS sağlar.
grant update (medrese_id, student_id, task_id, day, item, value)
  on public.task_entries to authenticated;
grant update (medrese_id, start_date, active)
  on public.task_programs to authenticated;

-- Güncellenen satır başka medreseye taşınsa bile orada öğrenci olmalı.
drop policy "task_entries: student updates own" on public.task_entries;
create policy "task_entries: student updates own" on public.task_entries
for update to authenticated
using (student_id = auth.uid() and public.can_write_task_day(medrese_id, day))
with check (
  student_id = auth.uid()
  and public.my_role(medrese_id) = 'student'
  and public.can_write_task_day(medrese_id, day)
);
