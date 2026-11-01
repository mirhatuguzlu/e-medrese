-- Bildirimler: her olay alıcı başına bir satır yazar; send-push fonksiyonu
-- gönderilmemiş satırları FCM ile telefonlara yollar.

create extension if not exists pg_net;
create extension if not exists pg_cron;

-- Cihaz bildirim adresleri. Bir cihaz son giriş yapan kullanıcıya aittir.
create table public.push_tokens (
  token text primary key,
  user_id uuid not null references public.profiles on delete cascade,
  updated_at timestamptz not null default now()
);

create index on public.push_tokens (user_id);

create table public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles on delete cascade,
  medrese_id uuid references public.medreses on delete cascade,
  -- task_started | task_paused | task_resumed | task_finished | announcement
  -- | period_ready | reminder
  kind text not null,
  title text not null,
  body text not null default '',
  created_at timestamptz not null default now(),
  read_at timestamptz,
  pushed_at timestamptz
);

create index on public.notifications (user_id, created_at desc);
create index on public.notifications (created_at) where pushed_at is null;

alter table public.push_tokens enable row level security;
alter table public.notifications enable row level security;

-- Token yazma register_push_token ile; kullanıcı yalnızca kendi tokenını siler.
create policy "push_tokens: own deletes" on public.push_tokens
for delete to authenticated using (user_id = auth.uid());

create policy "notifications: own reads" on public.notifications
for select to authenticated using (user_id = auth.uid());
create policy "notifications: own marks read" on public.notifications
for update to authenticated
using (user_id = auth.uid()) with check (user_id = auth.uid());

revoke insert, update on public.notifications from anon, authenticated;
grant update (read_at) on public.notifications to authenticated;

-- Cihaz başka hesapla açıldıysa token yeni kullanıcıya geçer.
create function public.register_push_token(t text) returns void
language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;
  insert into public.push_tokens (token, user_id) values (t, auth.uid())
  on conflict (token) do update set user_id = auth.uid(), updated_at = now();
end $$;

-- [m]'nin [roles] rolündeki üyelerine (işlemi yapan hariç) bildirim yazar.
create function public.notify_members(
  m uuid,
  roles public.member_role[],
  k text,
  t text,
  b text
) returns void
language sql security definer set search_path = '' as $$
  insert into public.notifications (user_id, medrese_id, kind, title, body)
  select user_id, m, k, t, b from public.medrese_members
  where medrese_id = m and role = any (roles)
    and user_id is distinct from auth.uid()
$$;

-- Yeni satırlar gelince send-push'u uyandırır; gönderilecekleri fonksiyon
-- kendisi çeker. Anahtar Vault'ta 'service_role_key' adıyla elle saklanır;
-- yoksa bildirim yalnızca uygulama içinde görünür.
create function public.ping_send_push() returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  k text := (select decrypted_secret from vault.decrypted_secrets
             where name = 'service_role_key');
begin
  if k is not null then
    perform net.http_post(
      url := 'https://abtsartfcblqeqwpsdxl.supabase.co/functions/v1/send-push',
      body := '{}'::jsonb,
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer ' || k
      )
    );
  end if;
  return null;
end $$;

create trigger on_notifications_inserted
after insert on public.notifications
for each statement execute function public.ping_send_push();

-- send-push gönderilmemiş bildirimleri alır ve gönderildi işaretler.
-- Eş zamanlı iki çağrı aynı satırı almaz.
create function public.claim_pending_pushes()
returns table (user_id uuid, kind text, title text, body text, tokens text[])
language sql security definer set search_path = '' as $$
  with claimed as (
    update public.notifications n set pushed_at = now()
    where n.id in (
      select id from public.notifications
      where pushed_at is null and created_at > now() - interval '1 hour'
      order by created_at
      limit 500
      for update skip locked
    )
    returning n.user_id, n.kind, n.title, n.body
  )
  select c.user_id, c.kind, c.title, c.body,
    array(select token from public.push_tokens p where p.user_id = c.user_id)
  from claimed c
$$;

-- Görev programı başlatma, durdurma, devam ve bitiş.
create function public.notify_task_program() returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  k text;
  t text;
  b text;
begin
  if new.active and (tg_op = 'INSERT' or not old.active) then
    k := 'task_started';
    t := 'Görevler başladı';
    b := 'Haftalık görevlerin başladı. Her gün işaretlemeyi unutma.';
  elsif tg_op = 'UPDATE' and old.active and not new.active then
    k := 'task_finished';
    t := 'Görevler bitti';
    b := 'Hocan görev programını bitirdi. Puanların kaydedildi.';
  elsif tg_op = 'UPDATE' and new.active and new.paused and not old.paused then
    k := 'task_paused';
    t := 'Görevler durduruldu';
    b := 'Hocan görevleri bir süreliğine durdurdu.';
  elsif tg_op = 'UPDATE' and new.active and old.paused and not new.paused then
    k := 'task_resumed';
    t := 'Görevler devam ediyor';
    b := 'Görevler yeniden başladı. İşaretlemeye devam edebilirsin.';
  else
    return null;
  end if;
  perform public.notify_members(new.medrese_id, array['student']::public.member_role[], k, t, b);
  return null;
end $$;

create trigger on_task_program_changed
after insert or update on public.task_programs
for each row execute function public.notify_task_program();

create function public.notify_announcement() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  perform public.notify_members(
    new.medrese_id,
    array['owner', 'teacher', 'student']::public.member_role[],
    'announcement',
    'Yeni duyuru: ' || new.title,
    left(new.body, 200)
  );
  return null;
end $$;

create trigger on_announcement_created
after insert on public.announcements
for each row execute function public.notify_announcement();

-- Her gün 00:05: dönemi dün biten medreselerin öğrencilerine.
create function public.notify_period_ready() returns void
language sql security definer set search_path = '' as $$
  insert into public.notifications (user_id, medrese_id, kind, title, body)
  select mm.user_id, p.medrese_id, 'period_ready', 'Yıldızların hazır',
    'Haftalık dönem bitti. Bugün yıldızlarını görüp puanını öğrenebilirsin.'
  from public.task_programs p
  join public.medrese_members mm
    on mm.medrese_id = p.medrese_id and mm.role = 'student'
  where p.active
    and public.today_tr() > p.start_date
    and (public.today_tr() - p.start_date) % 7 = 0
$$;

-- Her gün 21:00: bugün hiç işaretleme yapmamış öğrencilere.
create function public.notify_daily_reminder() returns void
language sql security definer set search_path = '' as $$
  insert into public.notifications (user_id, medrese_id, kind, title, body)
  select mm.user_id, p.medrese_id, 'reminder', 'Görevlerini işaretle',
    'Bugünkü görevlerini henüz işaretlemedin.'
  from public.task_programs p
  join public.medrese_members mm
    on mm.medrese_id = p.medrese_id and mm.role = 'student'
  where p.active and not p.paused and p.start_date <= public.today_tr()
    and not exists (
      select 1 from public.task_entries e
      where e.medrese_id = p.medrese_id and e.student_id = mm.user_id
        and e.day = public.today_tr()
    )
$$;

-- pg_cron UTC çalışır; Türkiye UTC+3 (yaz saati yok).
select cron.schedule('notify-period-ready', '5 21 * * *', 'select public.notify_period_ready()');
select cron.schedule('notify-daily-reminder', '0 18 * * *', 'select public.notify_daily_reminder()');

revoke execute on function
  public.register_push_token(text),
  public.notify_members(uuid, public.member_role[], text, text, text),
  public.claim_pending_pushes(),
  public.notify_period_ready(),
  public.notify_daily_reminder()
from public, anon, authenticated;
grant execute on function public.register_push_token(text) to authenticated;
grant execute on function public.claim_pending_pushes() to service_role;
