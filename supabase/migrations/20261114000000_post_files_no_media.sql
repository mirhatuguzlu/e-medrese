-- Depolama alanı (ücretsiz pakette toplam ~1 GB) videoya ve sese yetmez:
-- paylaşımlara yalnız fotoğraf ve PDF eklenir.

delete from public.post_files where kind in ('video', 'audio');

alter table public.post_files drop constraint post_files_kind_check;
alter table public.post_files
  add constraint post_files_kind_check check (kind in ('image', 'pdf'));

update storage.buckets set allowed_mime_types = array[
  'image/jpeg', 'image/png', 'image/webp', 'image/gif', 'image/heic',
  'application/pdf'
]
where id = 'post-files';
