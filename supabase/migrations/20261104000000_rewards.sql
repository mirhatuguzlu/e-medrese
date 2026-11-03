-- Ödüller: hocanın koyduğu birikmiş puan eşikleri. Öğrenci birini, bitiş
-- tarihiyle hedef seçer; uygulama haftalık görev önerisini hesaplar.

create table public.rewards (
  id uuid primary key default gen_random_uuid(),
  medrese_id uuid not null references public.medreses on delete cascade,
  title text not null check (length(trim(title)) between 1 and 200),
  description text not null default '' check (length(description) <= 2000),
  points numeric not null check (points > 0),
  created_by uuid default auth.uid() references public.profiles on delete set null,
  created_at timestamptz not null default now()
);

create index on public.rewards (medrese_id, points);

alter table public.rewards enable row level security;

create policy "rewards: members read" on public.rewards
for select to authenticated using (public.my_role(medrese_id) is not null);
create policy "rewards: staff write" on public.rewards
for insert to authenticated
with check (public.my_role(medrese_id) in ('owner', 'teacher'));
create policy "rewards: staff delete" on public.rewards
for delete to authenticated
using (public.my_role(medrese_id) in ('owner', 'teacher'));

revoke update on public.rewards from anon, authenticated;

-- Öğrencinin medresedeki tek hedefi; yalnız kendisi görür.
create table public.reward_goals (
  medrese_id uuid not null references public.medreses on delete cascade,
  student_id uuid not null default auth.uid() references public.profiles on delete cascade,
  reward_id uuid not null references public.rewards on delete cascade,
  deadline date not null,
  primary key (medrese_id, student_id)
);

alter table public.reward_goals enable row level security;

create policy "reward_goals: own" on public.reward_goals
for all to authenticated
using (student_id = auth.uid())
with check (
  student_id = auth.uid()
  and public.my_role(medrese_id) = 'student'
  and exists (
    select 1 from public.rewards r
    where r.id = reward_id and r.medrese_id = reward_goals.medrese_id
  )
);

-- Hedef görev takibinden türer: rıza geri alınınca o da silinir.
create or replace function public.revoke_task_consent() returns void
language sql security definer set search_path = '' as $$
  delete from public.task_entries where student_id = auth.uid();
  delete from public.weekly_scores where student_id = auth.uid();
  delete from public.reward_goals where student_id = auth.uid();
  delete from public.task_consents where user_id = auth.uid();
$$;
