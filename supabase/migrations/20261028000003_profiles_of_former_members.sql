-- Medreseden çıkan/çıkarılan kişinin adı, o medresede bıraktığı içerikte
-- görünmeye devam etsin ("İsimsiz" yerine).
create function public.can_see_profile(other uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select other = auth.uid()
    or public.shares_medrese(other)
    or exists (
      select 1 from public.posts p
      where p.author_id = other and public.my_role(p.medrese_id) is not null
    )
    or exists (
      select 1 from public.announcements a
      where a.author_id = other and public.my_role(a.medrese_id) is not null
    )
    or exists (
      select 1 from public.comments c
      join public.posts p on p.id = c.post_id
      where c.author_id = other and public.my_role(p.medrese_id) is not null
    )
$$;

create index on public.posts (author_id);
create index on public.announcements (author_id);
create index on public.comments (author_id);

drop policy "profiles: self or same medrese" on public.profiles;
create policy "profiles: self, same medrese or authored there" on public.profiles
for select to authenticated using (public.can_see_profile(id));
