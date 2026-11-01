-- Push'a dokununca ilgili sayfa açılsın diye bildirimin medresesi, paylaşımı
-- ve zamanı da gönderilir.
drop function public.claim_pending_pushes();
create function public.claim_pending_pushes()
returns table (
  user_id uuid, kind text, title text, body text, tokens text[],
  medrese_id uuid, post_id uuid, created_at timestamptz
)
language sql security definer set search_path = '' as $$
  with claimed as (
    update public.notifications n set pushed_at = now()
    where n.id in (
      select id from public.notifications
      where pushed_at is null and created_at > now() - interval '1 hour'
      order by created_at
      limit 500
      for update skip locked
    )
    returning n.user_id, n.kind, n.title, n.body, n.medrese_id, n.post_id, n.created_at
  )
  select c.user_id, c.kind, c.title, c.body,
    array(select token from public.push_tokens p where p.user_id = c.user_id),
    c.medrese_id, c.post_id, c.created_at
  from claimed c
$$;

revoke execute on function public.claim_pending_pushes() from public, anon, authenticated;
grant execute on function public.claim_pending_pushes() to service_role;
