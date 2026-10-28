-- Zaten üye olan (ör. kurucu) kendi koduyla "katıldın" mesajı almasın.
create or replace function public.join_medrese(code text) returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  m uuid;
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;
  select id into m from public.medreses where invite_code = upper(trim(code));
  if m is null then
    raise exception 'invalid invite code';
  end if;
  if public.my_role(m) is not null then
    raise exception 'already a member';
  end if;
  insert into public.medrese_members (medrese_id, user_id)
  values (m, auth.uid());
  return m;
end $$;
