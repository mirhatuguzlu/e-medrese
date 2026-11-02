-- Hukuki uyum: KVKK m.6 açık rızası, 5651 şikayet ve trafik bilgisi,
-- kurucu devri ve hesap silme.

-- 1) Görev takibi açık rızası (KVKK m.6) ----------------------------------
-- Namaz ve dini okuma girdileri din/inanç bilgisi verir: özel nitelikli veri.
-- Rıza yoksa girdi yazılamaz (öğrenci de hoca da); geri alınınca silinir.

create table public.task_consents (
  user_id uuid primary key references public.profiles on delete cascade,
  given_at timestamptz not null default now()
);

alter table public.task_consents enable row level security;

create policy "task_consents: read own" on public.task_consents
for select to authenticated using (user_id = auth.uid());

create function public.has_task_consent(u uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.task_consents where user_id = u)
$$;

create function public.give_task_consent() returns void
language sql security definer set search_path = '' as $$
  insert into public.task_consents (user_id) values (auth.uid())
  on conflict do nothing
$$;

-- Rıza geri alınınca girdiler ve onlardan hesaplanan puanlar silinir.
create function public.revoke_task_consent() returns void
language sql security definer set search_path = '' as $$
  delete from public.task_entries where student_id = auth.uid();
  delete from public.weekly_scores where student_id = auth.uid();
  delete from public.task_consents where user_id = auth.uid();
$$;

create function public.require_task_consent() returns trigger
language plpgsql set search_path = '' as $$
begin
  if not public.has_task_consent(new.student_id) then
    raise exception 'task consent required';
  end if;
  return new;
end $$;

create trigger task_entries_consent
before insert or update on public.task_entries
for each row execute function public.require_task_consent();

-- 2) Şikayetler (5651, 5846) ---------------------------------------------
-- İstemci yalnızca yazar; şikayetleri yer sağlayıcı Supabase panelinden
-- inceler. İçerik silinse de kanıt için metni saklanır.

create table public.reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid default auth.uid() references public.profiles on delete set null,
  post_id uuid references public.posts on delete set null,
  comment_id uuid references public.comments on delete set null,
  reason text not null check (reason in (
    'insult', 'illegal', 'copyright', 'privacy', 'spam', 'other'
  )),
  note text not null default '' check (length(note) <= 2000),
  content text not null,
  author_id uuid,
  status text not null default 'open' check (status in ('open', 'removed', 'rejected')),
  -- İçerik silinince ikisi de null olabilir; tam biri report_content'te zorunlu.
  created_at timestamptz not null default now()
);

alter table public.reports enable row level security;

-- Şikayet yalnızca görülebilen içerik için; metin ve yazar sunucuda doldurulur.
create function public.report_content(
  p uuid,
  c uuid,
  reason text,
  note text default ''
) returns void
language plpgsql security definer set search_path = '' as $$
declare
  body text;
  author uuid;
begin
  if (p is null) = (c is null) then
    raise exception 'not allowed';
  end if;
  if p is not null then
    select x.body, x.author_id into body, author from public.posts x
    where x.id = p and public.my_role(x.medrese_id) is not null;
  else
    select x.body, x.author_id into body, author
    from public.comments x join public.posts y on y.id = x.post_id
    where x.id = c and public.my_role(y.medrese_id) is not null;
  end if;
  if body is null then
    raise exception 'not allowed';
  end if;
  insert into public.reports (post_id, comment_id, reason, note, content, author_id)
  values (p, c, report_content.reason, trim(report_content.note), body, author);
end $$;

-- 3) Trafik bilgisi (5651 m.5) --------------------------------------------
-- İçerik oluşturma/düzenleme kaydı 2 yıl saklanır. Hesap silinse de kalır,
-- bu yüzden kullanıcıya yabancı anahtar yok. İstemci okuyamaz.

create table public.content_logs (
  id bigint generated always as identity primary key,
  user_id uuid,
  action text not null,
  table_name text not null,
  row_id uuid not null,
  ip text,
  created_at timestamptz not null default now()
);

alter table public.content_logs enable row level security;

create function public.log_content() returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  headers json := nullif(current_setting('request.headers', true), '')::json;
begin
  insert into public.content_logs (user_id, action, table_name, row_id, ip)
  values (
    auth.uid(),
    lower(tg_op),
    tg_table_name,
    new.id,
    trim(split_part(headers ->> 'x-forwarded-for', ',', 1))
  );
  return new;
end $$;

create trigger announcements_log after insert or update on public.announcements
for each row execute function public.log_content();
create trigger posts_log after insert or update on public.posts
for each row execute function public.log_content();
create trigger comments_log after insert or update on public.comments
for each row execute function public.log_content();
create trigger messages_log after insert or update on public.messages
for each row execute function public.log_content();

select cron.schedule(
  'purge-content-logs', '30 0 * * *',
  $$delete from public.content_logs where created_at < now() - interval '2 years'$$
);

-- 4) Kurucu devri ---------------------------------------------------------
-- Kurucu, medresenin başka bir üyesini kurucu yapar; kendisi hoca olur.

create function public.transfer_ownership(m uuid, u uuid) returns void
language plpgsql security definer set search_path = '' as $$
begin
  if public.my_role(m) is distinct from 'owner' or u = auth.uid()
    or public.role_of(m, u) is null then
    raise exception 'not allowed';
  end if;
  update public.medrese_members set role = 'owner'
  where medrese_id = m and user_id = u;
  update public.medrese_members set role = 'teacher'
  where medrese_id = m and user_id = auth.uid();
end $$;

-- 5) Hesap silme (KVKK m.7) -----------------------------------------------
-- Başka üyesi olan bir medresenin kurucusu önce kurucu devretmeli; tek
-- üyesi kendisi olan medreseler hesapla birlikte silinir. Diğer veriler
-- profiles'a bağlı cascade ile silinir.

create function public.delete_my_account() returns void
language plpgsql security definer set search_path = '' as $$
declare
  me uuid := auth.uid();
begin
  if me is null then
    raise exception 'not authenticated';
  end if;
  if exists (
    select 1 from public.medrese_members o
    join public.medrese_members x on x.medrese_id = o.medrese_id and x.user_id <> me
    where o.user_id = me and o.role = 'owner'
  ) then
    raise exception 'transfer ownership first';
  end if;
  delete from public.medreses
  where id in (
    select medrese_id from public.medrese_members where user_id = me and role = 'owner'
  );
  delete from auth.users where id = me;
end $$;

revoke execute on function
  public.give_task_consent(),
  public.revoke_task_consent(),
  public.report_content(uuid, uuid, text, text),
  public.transfer_ownership(uuid, uuid),
  public.delete_my_account()
from public, anon;
grant execute on function
  public.give_task_consent(),
  public.revoke_task_consent(),
  public.report_content(uuid, uuid, text, text),
  public.transfer_ownership(uuid, uuid),
  public.delete_my_account()
to authenticated;
