-- Online Medrese: kurslar ve YouTube dersleri. Kursları yönetici Supabase
-- panelinden girer; istemci yalnız yayındakileri okur. Ders ilerlemesi
-- (hangi dini dersi izlediği) KVKK m.6 özel nitelikli veridir: ayrı açık
-- rıza olmadan yazılamaz, rıza geri alınınca silinir.

create table public.courses (
  id uuid primary key default gen_random_uuid(),
  title text not null check (length(trim(title)) between 1 and 200),
  subtitle text not null default '' check (length(subtitle) <= 300),
  description text not null default '' check (length(description) <= 5000),
  -- Videodaki dersi veren hoca.
  teacher text not null default '' check (length(teacher) <= 200),
  category text not null check (category in (
    'kuran', 'akaid', 'fikih', 'hadis', 'siyer', 'risale', 'arapca', 'ahlak'
  )),
  -- Boşsa ilk dersin YouTube kapağı kullanılır.
  cover_url text not null default '',
  published boolean not null default false,
  sort int not null default 0,
  created_at timestamptz not null default now()
);

create table public.lessons (
  id uuid primary key default gen_random_uuid(),
  course_id uuid not null references public.courses on delete cascade,
  position int not null,
  -- Aynı başlıklı ardışık dersler bir bölümde listelenir.
  section text not null default '' check (length(section) <= 200),
  title text not null check (length(trim(title)) between 1 and 200),
  description text not null default '' check (length(description) <= 5000),
  youtube_id text not null check (youtube_id ~ '^[A-Za-z0-9_-]{11}$'),
  -- Katalogda süre göstermek için; 0 ise gösterilmez.
  duration_seconds int not null default 0 check (duration_seconds >= 0),
  unique (course_id, position)
);

alter table public.courses enable row level security;
alter table public.lessons enable row level security;

create policy "courses: read published" on public.courses
for select to authenticated using (published);
create policy "lessons: read published" on public.lessons
for select to authenticated using (
  exists (select 1 from public.courses c where c.id = course_id and c.published)
);

-- Kurs ilerlemesi açık rızası ---------------------------------------------

create table public.course_consents (
  user_id uuid primary key references public.profiles on delete cascade,
  given_at timestamptz not null default now()
);

alter table public.course_consents enable row level security;

create policy "course_consents: read own" on public.course_consents
for select to authenticated using (user_id = auth.uid());

create table public.lesson_progress (
  user_id uuid not null default auth.uid() references public.profiles on delete cascade,
  lesson_id uuid not null references public.lessons on delete cascade,
  -- Kaldığı saniye (devam etmek için).
  position_seconds int not null default 0 check (position_seconds >= 0),
  -- İzlediği en ileri saniye; ilk izleyişte bunun ötesine sarılamaz.
  watched_seconds int not null default 0 check (watched_seconds >= 0),
  completed_at timestamptz,
  updated_at timestamptz not null default now(),
  primary key (user_id, lesson_id)
);

create index on public.lesson_progress (user_id, updated_at desc);

alter table public.lesson_progress enable row level security;

create policy "lesson_progress: own" on public.lesson_progress
for all to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

revoke update on public.lesson_progress from anon, authenticated;
-- upsert bütün gönderilen sütunları günceller; anahtarlar da gerekir.
grant update (user_id, lesson_id, position_seconds, watched_seconds, completed_at)
on public.lesson_progress to authenticated;

create function public.give_course_consent() returns void
language sql security definer set search_path = '' as $$
  insert into public.course_consents (user_id) values (auth.uid())
  on conflict do nothing
$$;

create function public.revoke_course_consent() returns void
language sql security definer set search_path = '' as $$
  delete from public.lesson_progress where user_id = auth.uid();
  delete from public.course_consents where user_id = auth.uid();
$$;

-- Rıza şartı; izlenen en ileri saniye ve tamamlanma geri alınamaz.
create function public.guard_lesson_progress() returns trigger
language plpgsql set search_path = '' as $$
begin
  if not exists (
    select 1 from public.course_consents where user_id = new.user_id
  ) then
    raise exception 'course consent required';
  end if;
  if tg_op = 'UPDATE' then
    new.watched_seconds := greatest(new.watched_seconds, old.watched_seconds);
    new.completed_at := coalesce(old.completed_at, new.completed_at);
  end if;
  new.updated_at := now();
  return new;
end $$;

create trigger lesson_progress_guard
before insert or update on public.lesson_progress
for each row execute function public.guard_lesson_progress();

revoke execute on function
  public.give_course_consent(),
  public.revoke_course_consent()
from public, anon;
grant execute on function
  public.give_course_consent(),
  public.revoke_course_consent()
to authenticated;
