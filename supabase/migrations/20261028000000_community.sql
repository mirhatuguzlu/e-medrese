-- Topluluk modülü: medreseler, üyelik, duyurular, paylaşımlar, mesajlaşma.

create type public.member_role as enum ('owner', 'teacher', 'student');

-- Profiller ----------------------------------------------------------------

create table public.profiles (
  id uuid primary key references auth.users on delete cascade,
  full_name text not null default '',
  avatar_url text,
  created_at timestamptz not null default now()
);

create function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  insert into public.profiles (id, full_name)
  values (new.id, coalesce(new.raw_user_meta_data ->> 'full_name', ''));
  return new;
end $$;

create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_user();

-- Medreseler ve üyelik -------------------------------------------------------

create table public.medreses (
  id uuid primary key default gen_random_uuid(),
  name text not null check (length(trim(name)) between 1 and 100),
  description text not null default '',
  invite_code text not null unique
    default upper(substr(md5(gen_random_uuid()::text), 1, 8)),
  created_by uuid default auth.uid() references public.profiles on delete set null,
  created_at timestamptz not null default now()
);

create table public.medrese_members (
  medrese_id uuid references public.medreses on delete cascade,
  user_id uuid references public.profiles on delete cascade,
  role public.member_role not null default 'student',
  joined_at timestamptz not null default now(),
  primary key (medrese_id, user_id)
);

create index on public.medrese_members (user_id);

-- security definer: RLS politikalarında medrese_members'a özyinelemesiz erişim için.
create function public.my_role(m uuid) returns public.member_role
language sql stable security definer set search_path = '' as $$
  select role from public.medrese_members
  where medrese_id = m and user_id = auth.uid()
$$;

create function public.shares_medrese(other uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (
    select 1
    from public.medrese_members a
    join public.medrese_members b on a.medrese_id = b.medrese_id
    where a.user_id = auth.uid() and b.user_id = other
  )
$$;

-- Medreseyi kuran kişi otomatik olarak sahibi olur.
create function public.add_medrese_owner() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  insert into public.medrese_members (medrese_id, user_id, role)
  values (new.id, new.created_by, 'owner');
  return new;
end $$;

create trigger on_medrese_created
after insert on public.medreses
for each row execute function public.add_medrese_owner();

create function public.join_medrese(code text) returns uuid
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
  insert into public.medrese_members (medrese_id, user_id)
  values (m, auth.uid())
  on conflict do nothing;
  return m;
end $$;

-- Hoca öğrenci ekler; yalnızca sahip hoca ekleyebilir.
create function public.add_member_by_email(
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
  select id into target from auth.users where lower(auth.users.email) = lower(trim(email));
  if target is null then
    raise exception 'user not found';
  end if;
  insert into public.medrese_members (medrese_id, user_id, role)
  values (m, target, r)
  on conflict do nothing;
  return target;
end $$;

-- Duyurular, paylaşımlar, yorumlar -----------------------------------------

create table public.announcements (
  id uuid primary key default gen_random_uuid(),
  medrese_id uuid not null references public.medreses on delete cascade,
  author_id uuid not null default auth.uid() references public.profiles on delete cascade,
  title text not null check (length(trim(title)) between 1 and 200),
  body text not null default '',
  created_at timestamptz not null default now()
);

create table public.posts (
  id uuid primary key default gen_random_uuid(),
  medrese_id uuid not null references public.medreses on delete cascade,
  author_id uuid not null default auth.uid() references public.profiles on delete cascade,
  body text not null check (length(trim(body)) between 1 and 5000),
  created_at timestamptz not null default now()
);

create table public.comments (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.posts on delete cascade,
  author_id uuid not null default auth.uid() references public.profiles on delete cascade,
  body text not null check (length(trim(body)) between 1 and 2000),
  created_at timestamptz not null default now()
);

create index on public.announcements (medrese_id, created_at desc);
create index on public.posts (medrese_id, created_at desc);
create index on public.comments (post_id, created_at);

-- Mesajlaşma ----------------------------------------------------------------

create table public.conversations (
  id uuid primary key default gen_random_uuid(),
  medrese_id uuid not null references public.medreses on delete cascade,
  title text,
  created_by uuid default auth.uid() references public.profiles on delete set null,
  created_at timestamptz not null default now()
);

create table public.conversation_members (
  conversation_id uuid references public.conversations on delete cascade,
  user_id uuid references public.profiles on delete cascade,
  primary key (conversation_id, user_id)
);

create table public.messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.conversations on delete cascade,
  sender_id uuid not null default auth.uid() references public.profiles on delete cascade,
  body text not null check (length(trim(body)) between 1 and 5000),
  created_at timestamptz not null default now()
);

create index on public.conversation_members (user_id);
create index on public.messages (conversation_id, created_at desc);

create function public.in_conversation(c uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.conversation_members
    where conversation_id = c and user_id = auth.uid()
  )
$$;

-- Birebir veya grup sohbeti; herkes aynı medresenin üyesi olmalı.
create function public.create_conversation(
  m uuid,
  member_ids uuid[],
  title text default null
) returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  c uuid;
  ids uuid[] := array(select distinct unnest(member_ids || auth.uid()));
begin
  if public.my_role(m) is null then
    raise exception 'not allowed';
  end if;
  if array_length(ids, 1) < 2 then
    raise exception 'conversation needs at least two members';
  end if;
  if (select count(*) from public.medrese_members
      where medrese_id = m and user_id = any(ids)) <> array_length(ids, 1) then
    raise exception 'all members must belong to the medrese';
  end if;
  insert into public.conversations (medrese_id, title) values (m, title)
  returning id into c;
  insert into public.conversation_members (conversation_id, user_id)
  select c, unnest(ids);
  return c;
end $$;

-- Medreseden çıkan/çıkarılan kişi o medresenin sohbetlerinden de çıkar.
create function public.remove_from_medrese_conversations() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  delete from public.conversation_members cm
  using public.conversations c
  where cm.conversation_id = c.id
    and c.medrese_id = old.medrese_id
    and cm.user_id = old.user_id;
  return old;
end $$;

create trigger on_member_removed
after delete on public.medrese_members
for each row execute function public.remove_from_medrese_conversations();

-- RLS -----------------------------------------------------------------------

alter table public.profiles enable row level security;
alter table public.medreses enable row level security;
alter table public.medrese_members enable row level security;
alter table public.announcements enable row level security;
alter table public.posts enable row level security;
alter table public.comments enable row level security;
alter table public.conversations enable row level security;
alter table public.conversation_members enable row level security;
alter table public.messages enable row level security;

create policy "profiles: self or same medrese" on public.profiles
for select to authenticated using (id = auth.uid() or public.shares_medrese(id));
create policy "profiles: update self" on public.profiles
for update to authenticated using (id = auth.uid()) with check (id = auth.uid());

create policy "medreses: members read" on public.medreses
for select to authenticated using (public.my_role(id) is not null);
create policy "medreses: anyone creates own" on public.medreses
for insert to authenticated with check (created_by = auth.uid());
create policy "medreses: owner updates" on public.medreses
for update to authenticated using (public.my_role(id) = 'owner');
create policy "medreses: owner deletes" on public.medreses
for delete to authenticated using (public.my_role(id) = 'owner');

-- Üye ekleme yalnızca join_medrese / add_member_by_email üzerinden.
create policy "members: members read" on public.medrese_members
for select to authenticated using (public.my_role(medrese_id) is not null);
create policy "members: owner changes teacher/student role" on public.medrese_members
for update to authenticated
using (public.my_role(medrese_id) = 'owner' and role <> 'owner')
with check (role <> 'owner');
create policy "members: leave, or staff removes" on public.medrese_members
for delete to authenticated using (
  role <> 'owner' and (
    user_id = auth.uid()
    or public.my_role(medrese_id) = 'owner'
    or (role = 'student' and public.my_role(medrese_id) = 'teacher')
  )
);

create policy "announcements: members read" on public.announcements
for select to authenticated using (public.my_role(medrese_id) is not null);
create policy "announcements: staff write" on public.announcements
for insert to authenticated
with check (author_id = auth.uid() and public.my_role(medrese_id) in ('owner', 'teacher'));
create policy "announcements: author updates" on public.announcements
for update to authenticated using (author_id = auth.uid()) with check (author_id = auth.uid());
create policy "announcements: author or owner deletes" on public.announcements
for delete to authenticated
using (author_id = auth.uid() or public.my_role(medrese_id) = 'owner');

create policy "posts: members read" on public.posts
for select to authenticated using (public.my_role(medrese_id) is not null);
create policy "posts: members write" on public.posts
for insert to authenticated
with check (author_id = auth.uid() and public.my_role(medrese_id) is not null);
create policy "posts: author updates" on public.posts
for update to authenticated using (author_id = auth.uid()) with check (author_id = auth.uid());
create policy "posts: author or staff deletes" on public.posts
for delete to authenticated
using (author_id = auth.uid() or public.my_role(medrese_id) in ('owner', 'teacher'));

-- posts'un kendi RLS'i, yalnızca üyesi olunan medreselerin gönderilerini döndürür.
create policy "comments: members read" on public.comments
for select to authenticated using (exists (select 1 from public.posts p where p.id = post_id));
create policy "comments: members write" on public.comments
for insert to authenticated
with check (author_id = auth.uid() and exists (select 1 from public.posts p where p.id = post_id));
create policy "comments: author updates" on public.comments
for update to authenticated using (author_id = auth.uid()) with check (author_id = auth.uid());
create policy "comments: author or staff deletes" on public.comments
for delete to authenticated using (
  author_id = auth.uid()
  or exists (
    select 1 from public.posts p
    where p.id = post_id and public.my_role(p.medrese_id) in ('owner', 'teacher')
  )
);

-- Sohbet oluşturma yalnızca create_conversation üzerinden.
create policy "conversations: members read" on public.conversations
for select to authenticated using (public.in_conversation(id));
create policy "conversation_members: members read" on public.conversation_members
for select to authenticated using (public.in_conversation(conversation_id));
create policy "conversation_members: leave" on public.conversation_members
for delete to authenticated using (user_id = auth.uid());

create policy "messages: members read" on public.messages
for select to authenticated using (public.in_conversation(conversation_id));
create policy "messages: members send" on public.messages
for insert to authenticated
with check (sender_id = auth.uid() and public.in_conversation(conversation_id));

-- UPDATE yalnızca düzenlenebilir kolonlarda; aksi halde satır başka medreseye/kişiye taşınabilir.
revoke update on
  public.profiles, public.medreses, public.medrese_members,
  public.announcements, public.posts, public.comments,
  public.conversations, public.conversation_members, public.messages
from anon, authenticated;
grant update (full_name, avatar_url) on public.profiles to authenticated;
grant update (name, description, invite_code) on public.medreses to authenticated;
grant update (role) on public.medrese_members to authenticated;
grant update (title, body) on public.announcements to authenticated;
grant update (body) on public.posts to authenticated;
grant update (body) on public.comments to authenticated;

-- RPC'ler yalnızca giriş yapmış kullanıcılara açık.
revoke execute on function
  public.join_medrese(text),
  public.add_member_by_email(uuid, text, public.member_role),
  public.create_conversation(uuid, uuid[], text)
from public, anon;
grant execute on function
  public.join_medrese(text),
  public.add_member_by_email(uuid, text, public.member_role),
  public.create_conversation(uuid, uuid[], text)
to authenticated;

-- Realtime (postgres_changes RLS'e uyar).
alter publication supabase_realtime
add table public.messages, public.announcements, public.posts, public.comments;
