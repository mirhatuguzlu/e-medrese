-- Online Medrese: ders kaynakları (yöneticinin eklediği PDF ve web linkleri)
-- ve ders tartışması bildiriminin doğrudan o dersin tartışmasını açması.

-- 1) Ders kaynakları ------------------------------------------------------------
-- Dosya yüklenmez, yalnız https linki; öğrenci uygulama dışında açar.

create table public.lesson_resources (
  id uuid primary key default gen_random_uuid(),
  lesson_id uuid not null references public.lessons on delete cascade,
  position int not null default 0,
  title text not null check (length(trim(title)) between 1 and 200),
  url text not null check (url ~ '^https://[^\s/]+\.[^\s]+$' and length(url) <= 2000),
  created_at timestamptz not null default now()
);

create index on public.lesson_resources (lesson_id, position);

alter table public.lesson_resources enable row level security;

create policy "lesson_resources: read published" on public.lesson_resources
for select to authenticated using (
  exists (
    select 1 from public.lessons l join public.courses c on c.id = l.course_id
    where l.id = lesson_id and c.published
  )
);

create policy "lesson_resources: admin" on public.lesson_resources
for all to authenticated
using (public.is_app_admin())
with check (public.is_app_admin());

-- 2) Tartışma bildirimi dersi taşır ----------------------------------------------

alter table public.notifications
  add column lesson_id uuid references public.lessons on delete cascade;

create or replace function public.notify_lesson_comment() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if public.my_role(new.medrese_id) = 'student' then
    insert into public.notifications (user_id, medrese_id, lesson_id, kind, title, body)
    select user_id, new.medrese_id, new.lesson_id, 'lesson_comment',
      'Derste yeni soru', 'Bir öğrencin bir ders hakkında yazdı.'
    from public.medrese_members
    where medrese_id = new.medrese_id and role in ('owner', 'teacher')
      and user_id <> new.author_id;
  else
    insert into public.notifications (user_id, medrese_id, lesson_id, kind, title, body)
    select distinct c.author_id, new.medrese_id, new.lesson_id, 'lesson_comment',
      'Hocan derste cevap yazdı', 'Ders tartışmasını görmek için dokun.'
    from public.lesson_comments c
    join public.medrese_members mm
      on mm.medrese_id = c.medrese_id and mm.user_id = c.author_id
      and mm.role = 'student'
    where c.medrese_id = new.medrese_id and c.lesson_id = new.lesson_id
      and c.author_id <> new.author_id;
  end if;
  return null;
end $$;

-- Push'a dokununca tartışma açılsın diye ders de gönderilir (yalnız kimlik).
drop function public.claim_pending_pushes();
create function public.claim_pending_pushes()
returns table (
  user_id uuid, kind text, title text, body text, tokens text[],
  medrese_id uuid, post_id uuid, created_at timestamptz, lesson_id uuid
)
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
    returning n.user_id, n.kind, n.title, n.body, n.medrese_id, n.post_id,
      n.created_at, n.lesson_id
  )
  select c.user_id, c.kind, c.title, c.body,
    array(select token from public.push_tokens p where p.user_id = c.user_id),
    c.medrese_id, c.post_id, c.created_at, c.lesson_id
  from claimed c
$$;

revoke execute on function public.claim_pending_pushes() from public, anon, authenticated;
grant execute on function public.claim_pending_pushes() to service_role;
