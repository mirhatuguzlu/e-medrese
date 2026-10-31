-- Görevleri duraklatma ve bitirme.
-- Duraklatılan programda takvim akmaya devam eder, öğrenci işaretleyemez.
-- Bitirilen programda süren yarım dönem o ana kadarki girdilerle puanlanır.

alter table public.task_programs add column paused boolean not null default false;
grant update (paused) on public.task_programs to authenticated;

create or replace function public.can_write_task_day(m uuid, d date) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.task_programs p
    where p.medrese_id = m
      and p.active
      and not p.paused
      and d <= public.today_tr()
      and d >= p.start_date
        + 7 * ((public.today_tr() - p.start_date) / 7)
  )
$$;

-- Biten ve süren dönemleri kaydeder, programı kapatır.
create function public.finish_task_program(m uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare
  p date := public.current_period_start(m);
begin
  if public.my_role(m) is null or public.my_role(m) not in ('owner', 'teacher') then
    raise exception 'not allowed';
  end if;
  perform public.finalize_task_scores(m);
  if p is not null then
    insert into public.weekly_scores (medrese_id, student_id, period_start, total, details, note)
    select m, s.student_id, p, s.total, s.details, s.note
    from public.period_scores(m, p) s
    on conflict do nothing;
  end if;
  update public.task_programs set active = false, paused = false
  where medrese_id = m;
end $$;

revoke execute on function public.finish_task_program(uuid) from public, anon;
grant execute on function public.finish_task_program(uuid) to authenticated;
