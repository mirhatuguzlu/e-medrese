-- Paylaşımlara dosya: fotoğraf, video, ses, PDF (paylaşım başına en çok 5,
-- her biri en çok 50 MB). Dosya varsa yazı boş olabilir.
--
-- Dosyalar özel "post-files" kovasında "<medrese kimliği>/<ad>.<uzantı>"
-- yolunda durur; medresenin üyeleri görür. İndiren her üye dosya başına bir
-- kez kaydedilir ve paylaşana bildirim gider. Paylaşım ya da hesap silinmeden
-- önce uygulama dosyaları Storage API ile siler (SQL ile silinemiyor).

alter table public.posts drop constraint if exists posts_body_check;
alter table public.posts
  add constraint posts_body_check check (length(body) <= 5000);

create table public.post_files (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.posts on delete cascade,
  position int not null check (position between 1 and 5),
  kind text not null check (kind in ('image', 'video', 'audio', 'pdf')),
  name text not null check (length(trim(name)) between 1 and 200),
  path text not null unique,
  size bigint not null check (size between 1 and 52428800),
  created_at timestamptz not null default now(),
  unique (post_id, position)
);

create index on public.post_files (post_id);

alter table public.post_files enable row level security;

-- posts'un RLS'i yalnız üyesi olunan medreselerin paylaşımlarını döndürür.
create policy "post_files: members read" on public.post_files
for select to authenticated using (
  exists (select 1 from public.posts p where p.id = post_id)
);

-- Yalnız paylaşımın sahibi, kendi medresesinin klasörüne yüklediğini ekler.
create policy "post_files: author inserts" on public.post_files
for insert to authenticated with check (
  exists (
    select 1 from public.posts p
    where p.id = post_id and p.author_id = auth.uid()
      and path like p.medrese_id::text || '/%'
  )
);

-- shortcut: "yazı ya da dosya olmalı" kuralını uygulama uygular (dosyalar
-- paylaşımdan sonra eklenir); DB'de zorlamak gerekirse bir RPC'ye taşı.

-- Kova ----------------------------------------------------------------------

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('post-files', 'post-files', false, 52428800, array[
  'image/jpeg', 'image/png', 'image/webp', 'image/gif', 'image/heic',
  'video/mp4', 'video/quicktime', 'video/3gpp', 'video/webm',
  'audio/mpeg', 'audio/mp4', 'audio/aac', 'audio/ogg', 'audio/wav',
  'audio/x-m4a', 'audio/opus', 'audio/amr',
  'application/pdf'
])
on conflict (id) do update set
  public = false,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "post-files: members read" on storage.objects;
create policy "post-files: members read" on storage.objects
for select to authenticated using (
  bucket_id = 'post-files'
  and public.my_role(((storage.foldername(name))[1])::uuid) is not null
);

drop policy if exists "post-files: members upload" on storage.objects;
create policy "post-files: members upload" on storage.objects
for insert to authenticated with check (
  bucket_id = 'post-files'
  and public.my_role(((storage.foldername(name))[1])::uuid) is not null
);

-- Yükleyen ya da paylaşımı silebilen kurucu/hoca siler.
drop policy if exists "post-files: owner or staff delete" on storage.objects;
create policy "post-files: owner or staff delete" on storage.objects
for delete to authenticated using (
  bucket_id = 'post-files'
  and (
    owner_id = auth.uid()::text
    or public.my_role(((storage.foldername(name))[1])::uuid) in ('owner', 'teacher')
  )
);

-- İndirmeler ----------------------------------------------------------------

create table public.post_file_downloads (
  file_id uuid not null references public.post_files on delete cascade,
  user_id uuid not null references public.profiles on delete cascade,
  created_at timestamptz not null default now(),
  primary key (file_id, user_id)
);

alter table public.post_file_downloads enable row level security;
-- Yalnız record_post_download yazar; kimse doğrudan okumaz.

-- İndirmeyi kaydeder; ilk indirişte paylaşana bildirim gider.
create function public.record_post_download(f uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare
  file public.post_files;
  p public.posts;
  who text;
begin
  select * into file from public.post_files where id = f;
  select * into p from public.posts where id = file.post_id;
  if p.id is null or public.my_role(p.medrese_id) is null then
    raise exception 'not allowed';
  end if;
  insert into public.post_file_downloads (file_id, user_id)
  values (f, auth.uid()) on conflict do nothing;
  if not found or p.author_id = auth.uid() then
    return;
  end if;
  select coalesce(nullif(full_name, ''), 'İsimsiz') into who
  from public.profiles where id = auth.uid();
  insert into public.notifications (user_id, medrese_id, post_id, kind, title, body)
  values (p.author_id, p.medrese_id, p.id, 'post_download',
    'Dosyan indirildi', who || ', "' || file.name || '" dosyasını indirdi.');
end $$;

revoke execute on function public.record_post_download(uuid) from public, anon;
grant execute on function public.record_post_download(uuid) to authenticated;
