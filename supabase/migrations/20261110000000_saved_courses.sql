-- Kaydedilen kurslar sunucuda tutulur, telefonlar arasında eşitlenir. Hangi
-- dini kursla ilgilenildiğini gösterdiği için rıza sürümü 4 ister (metin
-- kaydedilen kursları da kapsar). Eski uygulamalar 2 ya da 3 yazmaya devam
-- eder; onlarda kaydetme zaten yalnız cihazdadır.

create or replace function public.give_course_consent(v int) returns void
language plpgsql security definer set search_path = '' as $$
begin
  if v not in (2, 3, 4) then
    raise exception 'unknown consent version';
  end if;
  insert into public.course_consents (user_id, version) values (auth.uid(), v)
  on conflict (user_id) do update set version = v, given_at = now();
end $$;

create table public.saved_courses (
  user_id uuid not null default auth.uid() references public.profiles on delete cascade,
  course_id uuid not null references public.courses on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, course_id)
);

alter table public.saved_courses enable row level security;

create policy "saved_courses: own read" on public.saved_courses
  for select to authenticated using (user_id = auth.uid());

create policy "saved_courses: own insert" on public.saved_courses
  for insert to authenticated
  with check (
    user_id = auth.uid()
    -- course_consent_version herkese açılmasın diye kendi rıza satırı okunur.
    and exists (
      select 1 from public.course_consents
      where user_id = auth.uid() and version >= 4
    )
  );

create policy "saved_courses: own delete" on public.saved_courses
  for delete to authenticated using (user_id = auth.uid());

-- Rıza geri alınınca kaydedilen kurslar da silinir.
create or replace function public.revoke_course_consent() returns void
language sql security definer set search_path = '' as $$
  update public.weekly_scores
  set total = total - coalesce((details ->> 'kurs')::numeric, 0),
    details = details - 'kurs'
  where student_id = auth.uid() and details ? 'kurs';
  delete from public.saved_courses where user_id = auth.uid();
  delete from public.course_reviews where user_id = auth.uid();
  delete from public.icazet_requests where user_id = auth.uid();
  delete from public.question_answers where user_id = auth.uid();
  delete from public.lesson_notes where user_id = auth.uid();
  delete from public.lesson_progress where user_id = auth.uid();
  delete from public.course_consents where user_id = auth.uid();
$$;
