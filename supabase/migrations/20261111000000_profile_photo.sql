-- Profil düzenleme: ad soyad ve profil fotoğrafı.
--
-- Fotoğraf özel (public olmayan) "avatars" kovasında, "<kullanıcı kimliği>/<ad>"
-- yolunda durur. Profili görebilen (bkz. can_see_profile) fotoğrafı da görür.
-- profiles.avatar_url bu yolu tutar. Hesap silinmeden önce uygulama fotoğrafı
-- Storage API ile siler (storage.objects SQL ile silinemiyor).
--
-- Uzak veritabanında bu adlarla elle eklenmiş kısıt/kova olabildiği için
-- her şey önce kaldırılıp bu tanımla yeniden kurulur.

alter table public.profiles
  drop constraint if exists profiles_full_name_length,
  drop constraint if exists profiles_avatar_own_folder;

-- Bu sürümden önce avatar_url yazılmıyordu; kova yoluna uymayan değer
-- (ör. dış bir resim adresi) gösterilemez, temizlenir.
update public.profiles set avatar_url = null
where avatar_url is not null and avatar_url not like id::text || '/%';

alter table public.profiles
  add constraint profiles_full_name_length check (char_length(full_name) <= 80),
  add constraint profiles_avatar_own_folder
    check (avatar_url is null or avatar_url like id::text || '/%');

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('avatars', 'avatars', false, 1048576, array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do update set
  public = false,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "avatars: visible with profile" on storage.objects;
create policy "avatars: visible with profile" on storage.objects
for select to authenticated using (
  bucket_id = 'avatars'
  and public.can_see_profile(((storage.foldername(name))[1])::uuid)
);

drop policy if exists "avatars: own insert" on storage.objects;
create policy "avatars: own insert" on storage.objects
for insert to authenticated with check (
  bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text
);

drop policy if exists "avatars: own delete" on storage.objects;
create policy "avatars: own delete" on storage.objects
for delete to authenticated using (
  bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text
);
