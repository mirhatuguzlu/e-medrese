-- Hoca bekleyen ödül isteğini nedeniyle reddeder; ayrılan puan öğrenciye
-- döner, öğrenciye neden bildirilir.

alter table public.reward_claims
  add column rejected_at timestamptz,
  add column reject_reason text;

-- Reddedilen isteğin puanı düşülmez.
create or replace function public.reward_balance(m uuid, s uuid) returns numeric
language sql stable security definer set search_path = '' as $$
  select coalesce((select sum(total) from public.weekly_scores
                   where medrese_id = m and student_id = s), 0)
       - coalesce((select sum(points) from public.reward_claims
                   where medrese_id = m and student_id = s and rejected_at is null), 0)
$$;

create or replace function public.request_reward(r uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare
  rw public.rewards;
  who text;
begin
  select * into rw from public.rewards where id = r;
  if rw.id is null or public.my_role(rw.medrese_id) is distinct from 'student' then
    raise exception 'not a student of this medrese';
  end if;
  -- Aynı öğrencinin eş zamanlı iki isteği puanı iki kez harcamasın.
  perform 1 from public.profiles where id = auth.uid() for update;
  if exists (select 1 from public.reward_claims
             where reward_id = r and student_id = auth.uid()
               and delivered_at is null and rejected_at is null) then
    raise exception 'already requested';
  end if;
  perform public.finalize_task_scores(rw.medrese_id);
  if public.reward_balance(rw.medrese_id, auth.uid()) < rw.points then
    raise exception 'not enough points';
  end if;
  insert into public.reward_claims (medrese_id, student_id, reward_id, title, points)
  values (rw.medrese_id, auth.uid(), r, rw.title, rw.points);

  select coalesce(nullif(full_name, ''), 'İsimsiz') into who
  from public.profiles where id = auth.uid();
  insert into public.notifications (user_id, medrese_id, reward_id, kind, title, body)
  select user_id, rw.medrese_id, r, 'reward_request', 'Ödül isteği',
    who || ' "' || rw.title || '" ödülüne ulaştı ve ödülünü istiyor.'
  from public.medrese_members
  where medrese_id = rw.medrese_id and role in ('owner', 'teacher');
end $$;

-- Bekleyen (teslim edilmemiş, reddedilmemiş) isteği hocalara kilitler.
create function public.pending_claim_for_staff(c uuid) returns public.reward_claims
language plpgsql security definer set search_path = '' as $$
declare
  cl public.reward_claims;
begin
  select * into cl from public.reward_claims where id = c for update;
  if cl.id is null
     or coalesce(public.my_role(cl.medrese_id)::text, '') not in ('owner', 'teacher') then
    raise exception 'not staff of this medrese';
  end if;
  if cl.delivered_at is not null or cl.rejected_at is not null then
    raise exception 'not pending';
  end if;
  return cl;
end $$;

create or replace function public.deliver_reward(c uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare
  cl public.reward_claims := public.pending_claim_for_staff(c);
begin
  update public.reward_claims set delivered_at = now(), delivered_by = auth.uid()
  where id = c;
  delete from public.reward_goals
  where medrese_id = cl.medrese_id and student_id = cl.student_id
    and reward_id = cl.reward_id;
end $$;

create function public.reject_reward(c uuid, reason text) returns void
language plpgsql security definer set search_path = '' as $$
declare
  cl public.reward_claims := public.pending_claim_for_staff(c);
  why text := trim(coalesce(reason, ''));
begin
  if length(why) not between 1 and 500 then
    raise exception 'reason required';
  end if;
  update public.reward_claims
  set rejected_at = now(), reject_reason = why
  where id = c;
  insert into public.notifications (user_id, medrese_id, reward_id, kind, title, body)
  values (cl.student_id, cl.medrese_id, cl.reward_id, 'reward_rejected',
    'Ödül isteğin reddedildi', '"' || cl.title || '": ' || why);
end $$;

revoke execute on function
  public.pending_claim_for_staff(uuid),
  public.reject_reward(uuid, text)
from public, anon;
revoke execute on function public.pending_claim_for_staff(uuid) from authenticated;
grant execute on function public.reject_reward(uuid, text) to authenticated;
