-- Private Circles: membership-gated spot sharing with expiring, revocable invites.
create schema if not exists private;

alter table public.spots
  add column is_public boolean not null default true;
create index spots_public_created_idx on public.spots (is_public, created_at desc, id desc);

create table public.circles (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id) on delete cascade,
  name text not null check (char_length(trim(name)) between 1 and 40),
  description text not null default '' check (char_length(description) <= 160),
  color text not null default '#6B9961' check (color ~ '^#[0-9A-Fa-f]{6}$'),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index circles_owner_id_idx on public.circles (owner_id);

create table public.circle_members (
  circle_id uuid not null references public.circles(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  role text not null default 'member' check (role in ('owner', 'admin', 'member')),
  joined_at timestamptz not null default now(),
  primary key (circle_id, user_id)
);
create index circle_members_user_id_idx on public.circle_members (user_id, circle_id);

create table public.spot_circles (
  spot_id uuid not null references public.spots(id) on delete cascade,
  circle_id uuid not null references public.circles(id) on delete cascade,
  shared_by uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (spot_id, circle_id)
);
create index spot_circles_circle_id_idx on public.spot_circles (circle_id, spot_id);

create table public.circle_invites (
  id uuid primary key default gen_random_uuid(),
  circle_id uuid not null references public.circles(id) on delete cascade,
  created_by uuid not null references public.profiles(id) on delete cascade,
  token_hash text not null unique,
  expires_at timestamptz not null,
  max_uses integer not null default 25 check (max_uses between 1 and 100),
  use_count integer not null default 0 check (use_count >= 0),
  revoked_at timestamptz,
  created_at timestamptz not null default now()
);
create index circle_invites_circle_id_idx on public.circle_invites (circle_id, created_at desc);

create or replace function private.is_circle_member(target_circle uuid, target_user uuid default auth.uid())
returns boolean language sql security definer stable set search_path = '' as $$
  select target_user is not null and exists (
    select 1 from public.circle_members
    where circle_id = target_circle and user_id = target_user
  );
$$;

create or replace function private.is_circle_admin(target_circle uuid, target_user uuid default auth.uid())
returns boolean language sql security definer stable set search_path = '' as $$
  select target_user is not null and exists (
    select 1 from public.circle_members
    where circle_id = target_circle and user_id = target_user and role in ('owner', 'admin')
  );
$$;

create or replace function private.can_view_spot(target_spot uuid, spot_owner uuid, globally_visible boolean)
returns boolean language sql security definer stable set search_path = '' as $$
  select globally_visible
    or spot_owner = auth.uid()
    or exists (
      select 1 from public.spot_circles sc
      join public.circle_members cm on cm.circle_id = sc.circle_id
      where sc.spot_id = target_spot and cm.user_id = auth.uid()
    );
$$;

revoke all on function private.is_circle_member(uuid, uuid) from public;
revoke all on function private.is_circle_admin(uuid, uuid) from public;
revoke all on function private.can_view_spot(uuid, uuid, boolean) from public;
grant usage on schema private to authenticated;
grant execute on function private.is_circle_member(uuid, uuid) to authenticated;
grant execute on function private.is_circle_admin(uuid, uuid) to authenticated;
grant execute on function private.can_view_spot(uuid, uuid, boolean) to anon, authenticated;

create or replace function private.add_circle_owner()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  insert into public.circle_members(circle_id, user_id, role)
  values (new.id, new.owner_id, 'owner');
  return new;
end;
$$;
create trigger circles_add_owner after insert on public.circles
for each row execute function private.add_circle_owner();

create trigger circles_set_updated_at before update on public.circles
for each row execute function public.set_updated_at();

alter table public.circles enable row level security;
alter table public.circle_members enable row level security;
alter table public.spot_circles enable row level security;
alter table public.circle_invites enable row level security;

revoke all on public.circles, public.circle_members, public.spot_circles, public.circle_invites from anon, authenticated;
grant select, insert, update, delete on public.circles to authenticated;
grant select, update, delete on public.circle_members to authenticated;
grant select, insert, delete on public.spot_circles to authenticated;

drop policy spots_public_read on public.spots;
create policy spots_anon_read on public.spots for select to anon using (is_public);
create policy spots_permitted_read on public.spots for select to authenticated
using (private.can_view_spot(id, owner_id, is_public));

drop policy ratings_public_read on public.ratings;
create policy ratings_anon_public_read on public.ratings for select to anon
using (exists (select 1 from public.spots where spots.id = ratings.spot_id and spots.is_public));
create policy ratings_permitted_read on public.ratings for select to authenticated
using (exists (select 1 from public.spots where spots.id = ratings.spot_id));

create policy circles_member_read on public.circles for select to authenticated
using (private.is_circle_member(id));
create policy circles_own_insert on public.circles for insert to authenticated
with check (auth.uid() = owner_id);
create policy circles_owner_update on public.circles for update to authenticated
using (auth.uid() = owner_id) with check (auth.uid() = owner_id);
create policy circles_owner_delete on public.circles for delete to authenticated
using (auth.uid() = owner_id);

create policy circle_members_member_read on public.circle_members for select to authenticated
using (private.is_circle_member(circle_id));
create policy circle_members_admin_update on public.circle_members for update to authenticated
using (private.is_circle_admin(circle_id) and role <> 'owner')
with check (private.is_circle_admin(circle_id) and role in ('admin', 'member'));
create policy circle_members_remove on public.circle_members for delete to authenticated
using (
  (auth.uid() = user_id and role <> 'owner')
  or (private.is_circle_admin(circle_id) and role <> 'owner')
);

create policy spot_circles_member_read on public.spot_circles for select to authenticated
using (private.is_circle_member(circle_id));
create policy spot_circles_owner_insert on public.spot_circles for insert to authenticated
with check (
  auth.uid() = shared_by
  and private.is_circle_member(circle_id)
  and exists (select 1 from public.spots where spots.id = spot_id and spots.owner_id = auth.uid())
);
create policy spot_circles_owner_delete on public.spot_circles for delete to authenticated
using (
  exists (select 1 from public.spots where spots.id = spot_id and spots.owner_id = auth.uid())
  or private.is_circle_admin(circle_id)
);

create or replace function public.create_circle_invite(target_circle uuid)
returns text language plpgsql security definer set search_path = '' as $$
declare raw_token text := encode(extensions.gen_random_bytes(24), 'hex');
begin
  if auth.uid() is null or not private.is_circle_admin(target_circle, auth.uid()) then
    raise exception 'Only circle admins can create invites';
  end if;
  insert into public.circle_invites(circle_id, created_by, token_hash, expires_at)
  values (target_circle, auth.uid(), encode(extensions.digest(raw_token, 'sha256'), 'hex'), now() + interval '7 days');
  return raw_token;
end;
$$;

create or replace function public.accept_circle_invite(raw_token text)
returns uuid language plpgsql security definer set search_path = '' as $$
declare invitation public.circle_invites%rowtype;
begin
  if auth.uid() is null then raise exception 'Sign in to accept this invite'; end if;
  select * into invitation from public.circle_invites
  where token_hash = encode(extensions.digest(raw_token, 'sha256'), 'hex')
    and revoked_at is null and expires_at > now() and use_count < max_uses
  for update;
  if invitation.id is null then raise exception 'This invite is invalid or expired'; end if;

  insert into public.circle_members(circle_id, user_id, role)
  values (invitation.circle_id, auth.uid(), 'member')
  on conflict do nothing;
  if found then
    update public.circle_invites set use_count = use_count + 1 where id = invitation.id;
  end if;
  return invitation.circle_id;
end;
$$;

create or replace function public.revoke_circle_invites(target_circle uuid)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is null or not private.is_circle_admin(target_circle, auth.uid()) then
    raise exception 'Only circle admins can revoke invites';
  end if;
  update public.circle_invites set revoked_at = now()
  where circle_id = target_circle and revoked_at is null;
end;
$$;

revoke all on function public.create_circle_invite(uuid) from public, anon;
revoke all on function public.accept_circle_invite(text) from public, anon;
revoke all on function public.revoke_circle_invites(uuid) from public, anon;
grant execute on function public.create_circle_invite(uuid) to authenticated;
grant execute on function public.accept_circle_invite(text) to authenticated;
grant execute on function public.revoke_circle_invites(uuid) to authenticated;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('circle-spot-photos', 'circle-spot-photos', false, 26214400, array['image/jpeg', 'image/png', 'image/heic', 'image/heif'])
on conflict (id) do update set public = false, file_size_limit = excluded.file_size_limit, allowed_mime_types = excluded.allowed_mime_types;

create policy circle_photos_permitted_read on storage.objects for select to authenticated
using (
  bucket_id = 'circle-spot-photos'
  and exists (
    select 1 from public.spots
    where spots.id = ((storage.foldername(name))[2])::uuid
  )
);
create policy circle_photos_own_insert on storage.objects for insert to authenticated
with check (
  bucket_id = 'circle-spot-photos'
  and (storage.foldername(name))[1] = auth.uid()::text
  and exists (
    select 1 from public.spots
    where spots.id = ((storage.foldername(name))[2])::uuid and spots.owner_id = auth.uid()
  )
);
create policy circle_photos_own_update on storage.objects for update to authenticated
using (bucket_id = 'circle-spot-photos' and owner_id = auth.uid()::text)
with check (bucket_id = 'circle-spot-photos' and (storage.foldername(name))[1] = auth.uid()::text);
create policy circle_photos_own_delete on storage.objects for delete to authenticated
using (bucket_id = 'circle-spot-photos' and owner_id = auth.uid()::text);
