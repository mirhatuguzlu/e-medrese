-- Ders kaynakları artık web linki değil, yöneticinin telefondan seçtiği PDF.
--
-- Dosya özel "lesson-files" kovasında "<ders kimliği>/<ad>.pdf" yolunda durur;
-- uygulama içinde açılır. Eski uygulamalar bozulmasın diye sütun adı `url`
-- kaldı, ama artık kovadaki yolu tutar. Eski linklerin hepsi silinir.

delete from public.lesson_resources;

alter table public.lesson_resources
  drop constraint if exists lesson_resources_url_check;

alter table public.lesson_resources
  add constraint lesson_resources_url_check
    check (url like lesson_id::text || '/%'
      and url ~ '^[^/]+/[A-Za-z0-9_-]{1,100}\.pdf$');

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('lesson-files', 'lesson-files', false, 52428800, array['application/pdf'])
on conflict (id) do update set
  public = false,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

-- Yayındaki kursun dersini okuyabilen, dosyasını da okur.
drop policy if exists "lesson-files: read published" on storage.objects;
create policy "lesson-files: read published" on storage.objects
for select to authenticated using (
  bucket_id = 'lesson-files'
  and (
    public.is_app_admin()
    or exists (
      select 1 from public.lessons l join public.courses c on c.id = l.course_id
      where l.id::text = (storage.foldername(name))[1] and c.published
    )
  )
);

drop policy if exists "lesson-files: admin insert" on storage.objects;
create policy "lesson-files: admin insert" on storage.objects
for insert to authenticated with check (
  bucket_id = 'lesson-files' and public.is_app_admin()
);

drop policy if exists "lesson-files: admin delete" on storage.objects;
create policy "lesson-files: admin delete" on storage.objects
for delete to authenticated using (
  bucket_id = 'lesson-files' and public.is_app_admin()
);
