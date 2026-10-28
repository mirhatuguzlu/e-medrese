-- 1) Düzenlenen duyuru/paylaşım "düzenlendi" olarak işaretlensin.
alter table public.announcements add column edited_at timestamptz;
alter table public.posts add column edited_at timestamptz;

create function public.set_edited_at() returns trigger
language plpgsql set search_path = '' as $$
begin
  new.edited_at := now();
  return new;
end $$;

create trigger announcements_edited
before update on public.announcements
for each row
when (old.title is distinct from new.title or old.body is distinct from new.body)
execute function public.set_edited_at();

create trigger posts_edited
before update on public.posts
for each row
when (old.body is distinct from new.body)
execute function public.set_edited_at();

-- 2) Hocalar yalnızca öğrencilerin (ve medreseden ayrılmışların) paylaşımlarını
--    silebilsin; kurucunun ve diğer hocaların paylaşımlarını değil.
create function public.role_of(m uuid, u uuid) returns public.member_role
language sql stable security definer set search_path = '' as $$
  select role from public.medrese_members where medrese_id = m and user_id = u
$$;

drop policy "posts: author or staff deletes" on public.posts;
create policy "posts: author, owner, or teacher for students" on public.posts
for delete to authenticated using (
  author_id = auth.uid()
  or public.my_role(medrese_id) = 'owner'
  or (
    public.my_role(medrese_id) = 'teacher'
    and coalesce(public.role_of(medrese_id, author_id), 'student') = 'student'
  )
);
