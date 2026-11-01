-- Paylaşıma yorum gelince paylaşım sahibine bildirim; dokununca paylaşım açılır.

alter table public.notifications
  add column post_id uuid references public.posts on delete cascade;

create function public.notify_comment() returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  p public.posts;
  who text;
begin
  select * into p from public.posts where id = new.post_id;
  if p.author_id = new.author_id then
    return null;
  end if;
  select coalesce(nullif(full_name, ''), 'İsimsiz') into who
  from public.profiles where id = new.author_id;
  insert into public.notifications (user_id, medrese_id, post_id, kind, title, body)
  values (p.author_id, p.medrese_id, p.id, 'comment',
    'Paylaşımına yorum geldi', who || ': ' || left(new.body, 200));
  return null;
end $$;

create trigger on_comment_created
after insert on public.comments
for each row execute function public.notify_comment();
