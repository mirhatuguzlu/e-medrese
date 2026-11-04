-- Online Medrese: kurs seviyesi ve kazanımlar, tekrar soruları, medrese içi
-- ders tartışması, hoca onaylı icazet, isimsiz kurs değerlendirmeleri ve
-- verilen kurslardaki derslerin haftalık görev puanına eklenmesi.

-- 1) Rıza sürümü 3 -----------------------------------------------------------
-- Sürüm 3 metni tekrar sorusu cevaplarını, değerlendirmeleri, icazet
-- isteklerini ve verilen kurslarda tamamlanan derslerin haftalık puana
-- eklenmesini de kapsar. Eski uygulamalar parametresiz fonksiyonla sürüm 2
-- yazmaya devam eder; yeni veriler sürüm 3 ister.

create function public.course_consent_version(u uuid) returns int
language sql stable security definer set search_path = '' as $$
  select coalesce(
    (select version from public.course_consents where user_id = u), 0
  )
$$;

create function public.give_course_consent(v int) returns void
language plpgsql security definer set search_path = '' as $$
begin
  if v not in (2, 3) then
    raise exception 'unknown consent version';
  end if;
  insert into public.course_consents (user_id, version) values (auth.uid(), v)
  on conflict (user_id) do update set version = v, given_at = now();
end $$;

-- 2) Kurs seviyesi ve kazanımlar ------------------------------------------------

alter table public.courses
  add column level text check (level in ('baslangic', 'orta', 'ileri')),
  -- Her satır bir kazanım ("Bu kursta öğreneceklerin").
  add column outcomes text not null default '' check (length(outcomes) <= 3000);

-- 3) Tekrar soruları -------------------------------------------------------------
-- Yönetici derse çoktan seçmeli soru ekler; öğrenci dersi bitirince çözer.
-- İlk cevabı kaydedilir (hocalar doğru sayısını görür), sonra istediği kadar
-- yeniden çözebilir.

create table public.lesson_questions (
  id uuid primary key default gen_random_uuid(),
  lesson_id uuid not null references public.lessons on delete cascade,
  position int not null default 0,
  question text not null check (length(trim(question)) between 1 and 1000),
  options text[] not null check (
    array_length(options, 1) between 2 and 5
    and array_position(options, '') is null
  ),
  -- Doğru şıkkın sırası (0'dan).
  answer int not null,
  explanation text not null default '' check (length(explanation) <= 2000),
  created_at timestamptz not null default now(),
  check (answer >= 0 and answer < array_length(options, 1))
);

create index on public.lesson_questions (lesson_id, position);

alter table public.lesson_questions enable row level security;

create policy "lesson_questions: read published" on public.lesson_questions
for select to authenticated using (
  exists (
    select 1 from public.lessons l join public.courses c on c.id = l.course_id
    where l.id = lesson_id and c.published
  )
);

create policy "lesson_questions: admin" on public.lesson_questions
for all to authenticated
using (public.is_app_admin())
with check (public.is_app_admin());

create table public.question_answers (
  user_id uuid not null default auth.uid() references public.profiles on delete cascade,
  question_id uuid not null references public.lesson_questions on delete cascade,
  choice int not null check (choice >= 0),
  correct boolean not null default false,
  answered_at timestamptz not null default now(),
  primary key (user_id, question_id)
);

alter table public.question_answers enable row level security;

create policy "question_answers: read own" on public.question_answers
for select to authenticated using (user_id = auth.uid());

create policy "question_answers: insert own" on public.question_answers
for insert to authenticated with check (user_id = auth.uid());

revoke update on public.question_answers from anon, authenticated;

-- Doğruluk sunucuda hesaplanır; rıza (sürüm 3) ve bitmiş ders şart.
create function public.guard_question_answer() returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  q public.lesson_questions;
begin
  if public.course_consent_version(new.user_id) < 3 then
    raise exception 'course consent required';
  end if;
  select * into q from public.lesson_questions where id = new.question_id;
  if not exists (
    select 1 from public.lesson_progress
    where user_id = new.user_id and lesson_id = q.lesson_id
      and completed_at is not null
  ) then
    raise exception 'lesson not completed';
  end if;
  new.correct := new.choice = q.answer;
  new.answered_at := now();
  return new;
end $$;

create trigger question_answers_guard
before insert on public.question_answers
for each row execute function public.guard_question_answer();

-- 4) Medrese içi ders tartışması ---------------------------------------------
-- Hocanın medreseye verdiği kursun dersleri hakkında yalnız o medresenin
-- üyeleri yazar ve okur. İsteğe bağlı olarak videonun bir anına bağlanır.

create function public.lesson_assigned(m uuid, l uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.course_assignments a
    join public.lessons x on x.course_id = a.course_id
    where a.medrese_id = m and x.id = l
  )
$$;

create table public.lesson_comments (
  id uuid primary key default gen_random_uuid(),
  medrese_id uuid not null references public.medreses on delete cascade,
  lesson_id uuid not null references public.lessons on delete cascade,
  author_id uuid not null default auth.uid() references public.profiles on delete cascade,
  seconds int check (seconds >= 0),
  body text not null check (length(trim(body)) between 1 and 2000),
  created_at timestamptz not null default now()
);

create index on public.lesson_comments (medrese_id, lesson_id, created_at);

alter table public.lesson_comments enable row level security;

create policy "lesson_comments: members read" on public.lesson_comments
for select to authenticated using (
  public.my_role(medrese_id) is not null
  and public.lesson_assigned(medrese_id, lesson_id)
);

create policy "lesson_comments: members write" on public.lesson_comments
for insert to authenticated with check (
  author_id = auth.uid()
  and public.my_role(medrese_id) is not null
  and public.lesson_assigned(medrese_id, lesson_id)
);

create policy "lesson_comments: author or staff deletes" on public.lesson_comments
for delete to authenticated using (
  author_id = auth.uid()
  or public.my_role(medrese_id) in ('owner', 'teacher')
);

revoke update on public.lesson_comments from anon, authenticated;

create trigger lesson_comments_log after insert on public.lesson_comments
for each row execute function public.log_content();

-- Öğrenci yazınca hocalara; hoca yazınca o derste yazmış öğrencilere.
-- Google'a giden metinde yazılan metin ve ders adı yok.
create function public.notify_lesson_comment() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if public.my_role(new.medrese_id) = 'student' then
    perform public.notify_members(
      new.medrese_id,
      array['owner', 'teacher']::public.member_role[],
      'lesson_comment',
      'Derste yeni soru',
      'Bir öğrencin bir ders hakkında yazdı.'
    );
  else
    insert into public.notifications (user_id, medrese_id, kind, title, body)
    select distinct c.author_id, new.medrese_id, 'lesson_comment',
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

create trigger on_lesson_comment_created
after insert on public.lesson_comments
for each row execute function public.notify_lesson_comment();

-- 5) Hoca onaylı icazet ---------------------------------------------------------
-- Hocanın verdiği kursu bitiren öğrenci icazet ister; o medresenin kurucusu
-- ya da hocası onaylar veya notuyla geri çevirir. Geri çevrilen yeniden
-- istenebilir. Hesap silinse de belgede kalsın diye onaylayanın adı saklanır.

create table public.icazet_requests (
  id uuid primary key default gen_random_uuid(),
  medrese_id uuid not null references public.medreses on delete cascade,
  course_id uuid not null references public.courses on delete cascade,
  user_id uuid not null default auth.uid() references public.profiles on delete cascade,
  status text not null default 'pending' check (status in ('pending', 'approved', 'rejected')),
  note text not null default '' check (length(note) <= 1000),
  decided_by uuid references public.profiles on delete set null,
  decided_by_name text not null default '',
  decided_at timestamptz,
  created_at timestamptz not null default now(),
  unique (medrese_id, course_id, user_id)
);

alter table public.icazet_requests enable row level security;

create policy "icazet_requests: own or staff reads" on public.icazet_requests
for select to authenticated using (
  user_id = auth.uid() or public.my_role(medrese_id) in ('owner', 'teacher')
);

revoke insert, update, delete on public.icazet_requests from anon, authenticated;

create function public.request_icazet(m uuid, c uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare
  total int;
  done int;
begin
  if public.my_role(m) is distinct from 'student'
    or public.course_consent_version(auth.uid()) < 3
    or not exists (
      select 1 from public.course_assignments a
      where a.medrese_id = m and a.course_id = c
    ) then
    raise exception 'not allowed';
  end if;
  select count(*) into total from public.lessons where course_id = c;
  select count(*) into done from public.lesson_progress lp
  join public.lessons l on l.id = lp.lesson_id
  where lp.user_id = auth.uid() and l.course_id = c and lp.completed_at is not null;
  if total = 0 or done < total then
    raise exception 'course not finished';
  end if;
  insert into public.icazet_requests (medrese_id, course_id, user_id)
  values (m, c, auth.uid())
  on conflict (medrese_id, course_id, user_id) do update
  set status = 'pending', note = '', decided_by = null, decided_by_name = '',
    decided_at = null, created_at = now()
  where public.icazet_requests.status = 'rejected';
  if found then
    perform public.notify_members(
      m,
      array['owner', 'teacher']::public.member_role[],
      'icazet_request',
      'Yeni icazet isteği',
      'Bir öğrencin kursu bitirip icazet istedi.'
    );
  end if;
end $$;

create function public.decide_icazet(r uuid, approve boolean, note text default '')
returns void
language plpgsql security definer set search_path = '' as $$
declare
  req public.icazet_requests;
begin
  select * into req from public.icazet_requests where id = r;
  if req is null or req.status <> 'pending'
    or coalesce(public.my_role(req.medrese_id)::text, '') not in ('owner', 'teacher') then
    raise exception 'not allowed';
  end if;
  update public.icazet_requests set
    status = case when approve then 'approved' else 'rejected' end,
    note = left(trim(coalesce(decide_icazet.note, '')), 1000),
    decided_by = auth.uid(),
    decided_by_name = coalesce(
      (select nullif(full_name, '') from public.profiles where id = auth.uid()), ''
    ),
    decided_at = now()
  where id = r;
  insert into public.notifications (user_id, medrese_id, kind, title, body)
  values (
    req.user_id, req.medrese_id,
    case when approve then 'icazet_approved' else 'icazet_rejected' end,
    case when approve then 'İcazetin onaylandı' else 'İcazet isteğin geri çevrildi' end,
    case when approve then 'Hocan icazetini onayladı. Görmek için dokun.'
      else 'Hocanın notunu görmek için dokun.' end
  );
end $$;

-- 6) İsimsiz kurs değerlendirmeleri ---------------------------------------------
-- En az bir dersini bitiren 1–5 yıldız ve isteğe bağlı yorum yazar. Kimin
-- yazdığı gösterilmez (hangi dini kursu aldığı görünmesin); 5651 için
-- yazan saklanır ve şikayet edilebilir.

create table public.course_reviews (
  id uuid primary key default gen_random_uuid(),
  course_id uuid not null references public.courses on delete cascade,
  user_id uuid not null default auth.uid() references public.profiles on delete cascade,
  rating int not null check (rating between 1 and 5),
  body text not null default '' check (length(body) <= 2000),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (course_id, user_id)
);

alter table public.course_reviews enable row level security;

create policy "course_reviews: read own" on public.course_reviews
for select to authenticated using (user_id = auth.uid());

create policy "course_reviews: delete own" on public.course_reviews
for delete to authenticated using (user_id = auth.uid());

create policy "course_reviews: admin" on public.course_reviews
for all to authenticated
using (public.is_app_admin())
with check (public.is_app_admin());

revoke insert, update on public.course_reviews from anon, authenticated;

create trigger course_reviews_log after insert or update on public.course_reviews
for each row execute function public.log_content();

create function public.save_review(c uuid, rating int, body text default '')
returns void
language plpgsql security definer set search_path = '' as $$
begin
  if public.course_consent_version(auth.uid()) < 3
    or not exists (select 1 from public.courses where id = c and published)
    or not exists (
      select 1 from public.lesson_progress lp
      join public.lessons l on l.id = lp.lesson_id
      where lp.user_id = auth.uid() and l.course_id = c
        and lp.completed_at is not null
    ) then
    raise exception 'not allowed';
  end if;
  insert into public.course_reviews (course_id, user_id, rating, body)
  values (c, auth.uid(), save_review.rating, trim(coalesce(save_review.body, '')))
  on conflict (course_id, user_id) do update
  set rating = excluded.rating, body = excluded.body, updated_at = now();
end $$;

create function public.course_reviews_of(c uuid)
returns table (id uuid, rating int, body text, created_at timestamptz, mine boolean)
language sql stable security definer set search_path = '' as $$
  select r.id, r.rating, r.body, r.updated_at, r.user_id = auth.uid()
  from public.course_reviews r
  join public.courses x on x.id = r.course_id and x.published
  where r.course_id = c
  order by (r.user_id = auth.uid()) desc, length(r.body) > 0 desc, r.updated_at desc
  limit 200
$$;

create function public.course_ratings()
returns table (course_id uuid, average numeric, count int)
language sql stable security definer set search_path = '' as $$
  select r.course_id, round(avg(r.rating), 1), count(*)::int
  from public.course_reviews r
  join public.courses x on x.id = r.course_id and x.published
  group by r.course_id
$$;

-- 7) Şikayet: ders tartışması ve değerlendirmeler ----------------------------

alter table public.reports
  add column lesson_comment_id uuid references public.lesson_comments on delete set null,
  add column review_id uuid references public.course_reviews on delete set null;

create function public.report_course_content(
  lc uuid,
  r uuid,
  reason text,
  note text default ''
) returns void
language plpgsql security definer set search_path = '' as $$
declare
  body text;
  author uuid;
begin
  if (lc is null) = (r is null) then
    raise exception 'not allowed';
  end if;
  if lc is not null then
    select x.body, x.author_id into body, author from public.lesson_comments x
    where x.id = lc and public.my_role(x.medrese_id) is not null
      and public.lesson_assigned(x.medrese_id, x.lesson_id);
  else
    select x.rating || ' yıldız: ' || x.body, x.user_id into body, author
    from public.course_reviews x join public.courses y on y.id = x.course_id
    where x.id = r and y.published;
  end if;
  if body is null then
    raise exception 'not allowed';
  end if;
  insert into public.reports (lesson_comment_id, review_id, reason, note, content, author_id)
  values (lc, r, report_course_content.reason, trim(report_course_content.note), body, author);
end $$;

-- 8) Görev puanı: verilen kurslarda tamamlanan dersler ------------------------
-- Hocanın medreseye verdiği kurslarda dönem içinde (Türkiye saatiyle)
-- tamamlanan her ders 5 puan, en fazla 10 ders. Yalnız sürüm 3 rızası
-- olanlar sayılır. Öğrenci bu göreve girdi yazamaz.

insert into public.task_definitions (id, title, description, sort, config) values
('kurs', 'Online kurs', 'Hocanın verdiği kurslarda bu hafta bitirdiğin her ders 5 puan. En fazla 10 ders (50 puan) sayılır.', 8,
 '{"kind":"course","target":1,"points":5,"cap":10}');

create or replace function public.student_writable_task(t text) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.task_definitions
    where id = t and config ->> 'kind' in ('checks', 'pages', 'weekly')
  )
$$;

create or replace function public.period_scores(m uuid, p date)
returns table (student_id uuid, total numeric, details jsonb, note text)
language sql stable security definer set search_path = '' as $$
  with students as (
    select user_id as student_id from public.medrese_members
    where medrese_id = m and role = 'student'
    union
    select e.student_id from public.task_entries e
    where e.medrese_id = m and e.day between p and p + 6
    union
    select g.student_id from public.uyum_grades g
    where g.medrese_id = m and g.period_start = p
  ),
  sums as (
    select e.student_id, e.task_id, sum(e.value) as s
    from public.task_entries e
    join public.task_definitions d on d.id = e.task_id
    where e.medrese_id = m and e.day between p and p + 6
      and d.config ->> 'kind' in ('checks', 'pages', 'weekly')
    group by 1, 2
    union all
    select g.student_id, 'uyum', g.points
    from public.uyum_grades g
    where g.medrese_id = m and g.period_start = p
    union all
    select lp.user_id, 'kurs', count(distinct lp.lesson_id)
    from public.lesson_progress lp
    join public.lessons l on l.id = lp.lesson_id
    join public.course_assignments a
      on a.course_id = l.course_id and a.medrese_id = m
    join public.course_consents cc
      on cc.user_id = lp.user_id and cc.version >= 3
    where (lp.completed_at at time zone 'Europe/Istanbul')::date between p and p + 6
    group by lp.user_id
  ),
  scored as (
    select st.student_id, d.id as task_id,
      round(
        least(coalesce(su.s, 0), (d.config ->> 'cap')::numeric)
          * (d.config ->> 'points')::numeric
          / (d.config ->> 'target')::numeric,
        4
      ) as pts
    from students st
    cross join public.task_definitions d
    left join sums su on su.student_id = st.student_id and su.task_id = d.id
  )
  select sc.student_id, sum(sc.pts), jsonb_object_agg(sc.task_id, sc.pts),
    coalesce(g.note, '')
  from scored sc
  left join public.uyum_grades g
    on g.medrese_id = m and g.period_start = p and g.student_id = sc.student_id
  group by sc.student_id, g.note
$$;

-- 9) Hocanın gördüğü ilerlemeye soru sonuçları ------------------------------

drop function public.assignment_progress(uuid, uuid);
create function public.assignment_progress(m uuid, c uuid)
returns table (
  user_id uuid,
  full_name text,
  consent boolean,
  done int,
  last_watched timestamptz,
  answered int,
  correct int
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
    ) end,
    case when cc.version >= 3 then (
      select count(*)::int from public.question_answers qa
      join public.lesson_questions q on q.id = qa.question_id
      join public.lessons l on l.id = q.lesson_id
      where qa.user_id = mm.user_id and l.course_id = c
    ) end,
    case when cc.version >= 3 then (
      select count(*)::int from public.question_answers qa
      join public.lesson_questions q on q.id = qa.question_id
      join public.lessons l on l.id = q.lesson_id
      where qa.user_id = mm.user_id and l.course_id = c and qa.correct
    ) end
  from public.medrese_members mm
  join public.profiles p on p.id = mm.user_id
  left join public.course_consents cc on cc.user_id = mm.user_id
  where mm.medrese_id = m and mm.role = 'student'
  order by p.full_name;
end $$;

-- 10) Rıza geri alınınca yeni veriler de silinir -----------------------------
-- Haftalık puanlardaki kurs payı düşülür; diğer görev puanları kalır.

create or replace function public.revoke_course_consent() returns void
language sql security definer set search_path = '' as $$
  update public.weekly_scores
  set total = total - coalesce((details ->> 'kurs')::numeric, 0),
    details = details - 'kurs'
  where student_id = auth.uid() and details ? 'kurs';
  delete from public.course_reviews where user_id = auth.uid();
  delete from public.icazet_requests where user_id = auth.uid();
  delete from public.question_answers where user_id = auth.uid();
  delete from public.lesson_notes where user_id = auth.uid();
  delete from public.lesson_progress where user_id = auth.uid();
  delete from public.course_consents where user_id = auth.uid();
$$;

-- Yetkiler -----------------------------------------------------------------------

revoke execute on function
  public.course_consent_version(uuid),
  public.give_course_consent(int),
  public.lesson_assigned(uuid, uuid),
  public.request_icazet(uuid, uuid),
  public.decide_icazet(uuid, boolean, text),
  public.save_review(uuid, int, text),
  public.course_reviews_of(uuid),
  public.course_ratings(),
  public.report_course_content(uuid, uuid, text, text),
  public.assignment_progress(uuid, uuid)
from public, anon;
-- lesson_assigned RLS kuralında çağrıldığı için okuyan da çalıştırabilmeli.
grant execute on function
  public.lesson_assigned(uuid, uuid),
  public.give_course_consent(int),
  public.request_icazet(uuid, uuid),
  public.decide_icazet(uuid, boolean, text),
  public.save_review(uuid, int, text),
  public.course_reviews_of(uuid),
  public.course_ratings(),
  public.report_course_content(uuid, uuid, text, text),
  public.assignment_progress(uuid, uuid)
to authenticated;
