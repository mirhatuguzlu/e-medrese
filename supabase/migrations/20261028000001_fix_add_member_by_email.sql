-- `email` parametresi auth.users.email kolonuyla çakışıyordu (42702).
create or replace function public.add_member_by_email(
  m uuid,
  email text,
  r public.member_role default 'student'
) returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  caller public.member_role := public.my_role(m);
  target uuid;
begin
  if r = 'owner'
    or caller is null
    or caller = 'student'
    or (r = 'teacher' and caller <> 'owner') then
    raise exception 'not allowed';
  end if;
  select u.id into target from auth.users u
  where lower(u.email) = lower(trim(add_member_by_email.email));
  if target is null then
    raise exception 'user not found';
  end if;
  insert into public.medrese_members (medrese_id, user_id, role)
  values (m, target, r)
  on conflict do nothing;
  return target;
end $$;
