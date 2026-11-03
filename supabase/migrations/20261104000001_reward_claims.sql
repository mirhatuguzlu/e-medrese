-- Ödül istekleri: öğrenci eşiğe ulaşınca "Ödülü iste"ye basar; hoca yalnız
-- istenmiş ödülü teslim edildi işaretler. Teslim edilen ödülün puanı birikmiş
-- puandan düşer. İstek bildirime bağlı değildir: bildirim gitmese de istek
-- kaydı vardır.

create table public.reward_claims (
  id uuid primary key default gen_random_uuid(),
  medrese_id uuid not null references public.medreses on delete cascade,
  student_id uuid not null references public.profiles on delete cascade,
  -- Ödül sonradan silinse de düşülen puan ve adı kalır.
  reward_id uuid references public.rewards on delete set null,
  title text not null,
  points numeric not null,
  requested_at timestamptz not null default now(),
  delivered_at timestamptz,
  delivered_by uuid references public.profiles on delete set null
);

create index on public.reward_claims (medrese_id, student_id);

alter table public.reward_claims enable row level security;

create policy "reward_claims: own or staff read" on public.reward_claims
for select to authenticated
using (student_id = auth.uid() or public.my_role(medrese_id) in ('owner', 'teacher'));

revoke insert, update, delete on public.reward_claims from anon, authenticated;

alter table public.notifications
  add column reward_id uuid references public.rewards on delete set null;

-- Öğrencinin istenebilir puanı: biten haftalar - teslim edilen ve bekleyen istekler.
create function public.reward_balance(m uuid, s uuid) returns numeric
language sql stable security definer set search_path = '' as $$
  select coalesce((select sum(total) from public.weekly_scores
                   where medrese_id = m and student_id = s), 0)
       - coalesce((select sum(points) from public.reward_claims
                   where medrese_id = m and student_id = s), 0)
$$;

create function public.request_reward(r uuid) returns void
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
             where reward_id = r and student_id = auth.uid() and delivered_at is null) then
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

-- Yalnız istenmiş, teslim edilmemiş ödül işaretlenir. Bu ödül hedefse hedef kalkar.
create function public.deliver_reward(c uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare
  cl public.reward_claims;
begin
  select * into cl from public.reward_claims where id = c for update;
  if cl.id is null
     or coalesce(public.my_role(cl.medrese_id)::text, '') not in ('owner', 'teacher') then
    raise exception 'not staff of this medrese';
  end if;
  if cl.delivered_at is not null then
    raise exception 'already delivered';
  end if;
  update public.reward_claims set delivered_at = now(), delivered_by = auth.uid()
  where id = c;
  delete from public.reward_goals
  where medrese_id = cl.medrese_id and student_id = cl.student_id
    and reward_id = cl.reward_id;
end $$;

-- Yeni ödül öğrencilere bildirilir.
create function public.notify_reward() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  insert into public.notifications (user_id, medrese_id, reward_id, kind, title, body)
  select user_id, new.medrese_id, new.id, 'reward', 'Yeni ödül: ' || new.title,
    trim_scale(new.points)::text || ' birikmiş puana ulaşınca isteyebilirsin.'
  from public.medrese_members
  where medrese_id = new.medrese_id and role = 'student';
  return null;
end $$;

create trigger on_reward_created
after insert on public.rewards
for each row execute function public.notify_reward();

-- İstekler görev puanından türer: rıza geri alınınca onlar da silinir.
create or replace function public.revoke_task_consent() returns void
language sql security definer set search_path = '' as $$
  delete from public.task_entries where student_id = auth.uid();
  delete from public.weekly_scores where student_id = auth.uid();
  delete from public.reward_goals where student_id = auth.uid();
  delete from public.reward_claims where student_id = auth.uid();
  delete from public.task_consents where user_id = auth.uid();
$$;

revoke execute on function
  public.reward_balance(uuid, uuid),
  public.request_reward(uuid),
  public.deliver_reward(uuid)
from public, anon;
revoke execute on function public.reward_balance(uuid, uuid) from authenticated;
grant execute on function
  public.request_reward(uuid),
  public.deliver_reward(uuid)
to authenticated;
