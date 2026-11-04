-- Uygulama yöneticileri kursları ve dersleri uygulamadan yönetir.
-- Yönetici eklemek için (SQL Editor'da bir kez):
--   insert into public.app_admins (user_id)
--   select id from auth.users where email = '<e-posta>';

create table public.app_admins (
  user_id uuid primary key references public.profiles on delete cascade,
  created_at timestamptz not null default now()
);

alter table public.app_admins enable row level security;

-- Yalnız kendi satırını görür; ekleme/silme panelden yapılır.
create policy "app_admins: read own" on public.app_admins
for select to authenticated using (user_id = auth.uid());

create function public.is_app_admin() returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.app_admins where user_id = auth.uid())
$$;

revoke execute on function public.is_app_admin() from public, anon;
grant execute on function public.is_app_admin() to authenticated;

-- Yönetici taslaklar dahil bütün kursları görür ve değiştirir.
create policy "courses: admin" on public.courses
for all to authenticated
using (public.is_app_admin())
with check (public.is_app_admin());

create policy "lessons: admin" on public.lessons
for all to authenticated
using (public.is_app_admin())
with check (public.is_app_admin());

-- İlerleme doğrulaması: izlenen süre gerçek zamandan hızlı artamaz (en çok
-- 2x hız ve 30 sn pay); tamamlanma için dersin %90'ı izlenmiş olmalı.
create or replace function public.guard_lesson_progress() returns trigger
language plpgsql set search_path = '' as $$
declare
  duration int;
begin
  if not exists (
    select 1 from public.course_consents where user_id = new.user_id
  ) then
    raise exception 'course consent required';
  end if;
  if tg_op = 'UPDATE' then
    new.watched_seconds := least(
      greatest(new.watched_seconds, old.watched_seconds),
      old.watched_seconds
        + ceil(extract(epoch from now() - old.updated_at) * 2)::int + 30
    );
  else
    new.watched_seconds := least(new.watched_seconds, 60);
  end if;

  if tg_op = 'UPDATE' and old.completed_at is not null then
    new.completed_at := old.completed_at;
  elsif new.completed_at is not null then
    select l.duration_seconds into duration
    from public.lessons l where l.id = new.lesson_id;
    -- Süresi girilmemiş derste doğrulanamaz; kabul edilir.
    new.completed_at := case
      when duration > 0 and new.watched_seconds < duration * 0.9 - 30 then null
      else now()
    end;
  end if;

  -- Bitmemiş derste izlenmemiş yerden devam edilmez.
  if new.completed_at is null then
    new.position_seconds := least(new.position_seconds, new.watched_seconds);
  end if;
  new.updated_at := now();
  return new;
end $$;

-- Derslerin sırasını [p_ids] sırasına göre 1'den başlatır. Önce eksiye
-- çekilir ki unique (course_id, position) ara adımda çakışmasın.
create function public.reorder_lessons(p_course uuid, p_ids uuid[])
returns void language plpgsql set search_path = '' as $$
begin
  if not public.is_app_admin() then
    raise exception 'not allowed';
  end if;
  update public.lessons set position = -position where course_id = p_course;
  update public.lessons l set position = o.ord
  from unnest(p_ids) with ordinality as o(id, ord)
  where l.id = o.id and l.course_id = p_course;
end $$;

revoke execute on function public.reorder_lessons(uuid, uuid[]) from public, anon;
grant execute on function public.reorder_lessons(uuid, uuid[]) to authenticated;
