-- Online Medrese: ilerleme kaydı düzeltmesi, hocanın medreseye kurs vermesi
-- ve hocaların öğrenci ilerlemesini görmesi.

-- 1) İlerleme doğrulaması upsert ile çalışsın --------------------------------
-- PostgREST upsert önce INSERT tetikleyicisini çalıştırır; satır zaten varsa
-- EXCLUDED bu tetikleyicinin değiştirdiği değerleri taşır. Eski sürüm INSERT
-- yolunda izlenen süreyi 60 sn'ye kesip tamamlanmayı sildiği için ilerleme
-- 60 sn'de takılıyordu. Satır varsa doğrulama UPDATE tetikleyicisine kalır.
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
  if tg_op = 'INSERT' then
    if exists (
      select 1 from public.lesson_progress
      where user_id = new.user_id and lesson_id = new.lesson_id
    ) then
      return new;
    end if;
    new.watched_seconds := least(new.watched_seconds, 60);
  else
    -- Gerçek zamandan hızlı artamaz: en çok 2x hız ve 30 sn pay.
    new.watched_seconds := least(
      greatest(new.watched_seconds, old.watched_seconds),
      old.watched_seconds
        + ceil(extract(epoch from now() - old.updated_at) * 2)::int + 30
    );
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

  if new.completed_at is null then
    new.position_seconds := least(new.position_seconds, new.watched_seconds);
  end if;
  new.updated_at := now();
  return new;
end $$;

-- 2) Rıza sürümü ---------------------------------------------------------------
-- Sürüm 2 metni, hocanın verdiği kurslardaki ilerlemenin o medresenin
-- hocalarına gösterilmesini de kapsar. Sürüm 1 verenlerin ilerlemesi
-- kaydedilmeye devam eder ama hocalara gösterilmez; uygulama yeniden sorar.
alter table public.course_consents add column version int not null default 1;

create or replace function public.give_course_consent() returns void
language sql security definer set search_path = '' as $$
  insert into public.course_consents (user_id, version) values (auth.uid(), 2)
  on conflict (user_id) do update set version = 2, given_at = now()
$$;

-- 3) Hocanın medreseye verdiği kurslar --------------------------------------

create table public.course_assignments (
  medrese_id uuid not null references public.medreses on delete cascade,
  course_id uuid not null references public.courses on delete cascade,
  assigned_by uuid default auth.uid() references public.profiles on delete set null,
  -- Bitirme tarihi (isteğe bağlı).
  due_on date,
  created_at timestamptz not null default now(),
  primary key (medrese_id, course_id)
);

alter table public.course_assignments enable row level security;

create policy "course_assignments: members read" on public.course_assignments
for select to authenticated using (public.my_role(medrese_id) is not null);

create policy "course_assignments: staff insert" on public.course_assignments
for insert to authenticated with check (
  public.my_role(medrese_id) in ('owner', 'teacher')
  and exists (select 1 from public.courses c where c.id = course_id and c.published)
);

create policy "course_assignments: staff delete" on public.course_assignments
for delete to authenticated
using (public.my_role(medrese_id) in ('owner', 'teacher'));

revoke update on public.course_assignments from anon, authenticated;

-- Öğrencilere bildirim; Google'a giden metinde kurs adı yok.
create function public.notify_course_assignment() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  perform public.notify_members(
    new.medrese_id,
    array['student']::public.member_role[],
    'course_assigned',
    'Hocan yeni bir kurs verdi',
    'Online Medrese''de görmek için dokun.'
  );
  return null;
end $$;

create trigger on_course_assigned
after insert on public.course_assignments
for each row execute function public.notify_course_assignment();

-- 4) Hocanın gördüğü öğrenci ilerlemesi --------------------------------------
-- Yalnız medresenin hocaları, yalnız verilen kurs için, yalnız sürüm 2
-- rızası olan öğrencilerin ilerlemesini görür.
create function public.assignment_progress(m uuid, c uuid)
returns table (
  user_id uuid,
  full_name text,
  consent boolean,
  done int,
  last_watched timestamptz
)
language plpgsql stable security definer set search_path = '' as $$
begin
  if coalesce(public.my_role(m)::text, '') not in ('owner', 'teacher') or not exists (
    select 1 from public.course_assignments a
    where a.medrese_id = m and a.course_id = c
  ) then
    raise exception 'not staff of this medrese';
  end if;
  return query
  select
    mm.user_id,
    p.full_name,
    coalesce(cc.version >= 2, false),
    case when cc.version >= 2 then (
      select count(*)::int from public.lesson_progress lp
      join public.lessons l on l.id = lp.lesson_id
      where lp.user_id = mm.user_id and l.course_id = c
        and lp.completed_at is not null
    ) end,
    case when cc.version >= 2 then (
      select max(lp.updated_at) from public.lesson_progress lp
      join public.lessons l on l.id = lp.lesson_id
      where lp.user_id = mm.user_id and l.course_id = c
    ) end
  from public.medrese_members mm
  join public.profiles p on p.id = mm.user_id
  left join public.course_consents cc on cc.user_id = mm.user_id
  where mm.medrese_id = m and mm.role = 'student'
  order by p.full_name;
end $$;

revoke execute on function public.assignment_progress(uuid, uuid) from public, anon;
grant execute on function public.assignment_progress(uuid, uuid) to authenticated;

-- 5) Ders notları --------------------------------------------------------------
-- Öğrencinin bir dersin belli bir saniyesine yazdığı notlar; yalnız kendisi
-- görür. Kurs rızası kapsamındadır, rıza geri alınınca silinir.
create table public.lesson_notes (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references public.profiles on delete cascade,
  lesson_id uuid not null references public.lessons on delete cascade,
  seconds int not null check (seconds >= 0),
  body text not null check (length(trim(body)) between 1 and 2000),
  created_at timestamptz not null default now()
);

create index on public.lesson_notes (user_id, lesson_id);

alter table public.lesson_notes enable row level security;

create policy "lesson_notes: read own" on public.lesson_notes
for select to authenticated using (user_id = auth.uid());

create policy "lesson_notes: insert own with consent" on public.lesson_notes
for insert to authenticated with check (
  user_id = auth.uid()
  and exists (select 1 from public.course_consents where user_id = auth.uid())
);

create policy "lesson_notes: delete own" on public.lesson_notes
for delete to authenticated using (user_id = auth.uid());

revoke update on public.lesson_notes from anon, authenticated;

create or replace function public.revoke_course_consent() returns void
language sql security definer set search_path = '' as $$
  delete from public.lesson_notes where user_id = auth.uid();
  delete from public.lesson_progress where user_id = auth.uid();
  delete from public.course_consents where user_id = auth.uid();
$$;
