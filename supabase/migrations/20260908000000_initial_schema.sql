-- GetOut's complete Supabase schema. SwiftData is only an offline cache.
-- Every client-visible table has RLS and explicit grants.

create extension if not exists pgcrypto with schema extensions;

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  username text not null,
  display_name text not null,
  bio text not null default '',
  avatar_system_image text not null default 'person.fill',
  cities_visited text[] not null default '{}',
  preferred_categories text[] not null default '{}',
  preferred_tags text[] not null default '{}',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint profiles_username_format check (username ~ '^[a-z0-9_]{3,24}$')
);
create unique index profiles_username_unique_ci on public.profiles (lower(username));

create table public.spots (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id) on delete cascade,
  title text not null,
  details text not null default '',
  latitude double precision not null,
  longitude double precision not null,
  address text not null default '',
  city text not null default '',
  neighborhood text not null default '',
  category text not null,
  rating double precision not null default 0,
  visit_hour integer not null default -1 check (visit_hour between -1 and 23),
  visit_weekday integer not null default -1 check (visit_weekday between -1 and 7),
  photo_urls text[] not null default '{}',
  tags text[] not null default '{}',
  contains_cannabis boolean not null default false,
  country_code text not null default '',
  administrative_area text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint spots_latitude_range check (latitude between -90 and 90),
  constraint spots_longitude_range check (longitude between -180 and 180)
);
create index spots_created_at_idx on public.spots (created_at desc, id desc);
create index spots_owner_id_idx on public.spots (owner_id);

create table public.likes (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  spot_id uuid not null references public.spots(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (user_id, spot_id)
);

create table public.saves (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  spot_id uuid not null references public.spots(id) on delete cascade,
  list text not null default 'saved' check (list in ('saved', 'beenThere')),
  created_at timestamptz not null default now(),
  unique (user_id, spot_id, list)
);

create table public.ratings (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  spot_id uuid not null references public.spots(id) on delete cascade,
  stars integer not null check (stars between 1 and 5),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, spot_id)
);

create table public.trips (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id) on delete cascade,
  title text not null,
  summary text not null default '',
  plan_summary text not null default '',
  start_date timestamptz,
  end_date timestamptz,
  cover_system_image text not null default 'suitcase',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index trips_owner_id_idx on public.trips (owner_id);

create table public.trip_stops (
  id uuid primary key default gen_random_uuid(),
  trip_id uuid not null references public.trips(id) on delete cascade,
  spot_id uuid not null references public.spots(id) on delete cascade,
  day_index integer not null default 0 check (day_index >= 0),
  sort_order integer not null default 0 check (sort_order >= 0),
  notes text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (trip_id, spot_id)
);

create table public.interactions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  spot_id uuid not null references public.spots(id) on delete cascade,
  event text not null check (event in ('view', 'like', 'save', 'dismiss')),
  context_city text not null default '',
  created_at timestamptz not null default now()
);
create index interactions_user_created_idx on public.interactions (user_id, created_at desc);

create table public.user_blocks (
  id uuid primary key default gen_random_uuid(),
  blocker_id uuid not null references public.profiles(id) on delete cascade,
  blocked_user_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (blocker_id, blocked_user_id),
  check (blocker_id <> blocked_user_id)
);

create table public.reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references public.profiles(id) on delete cascade,
  target_id uuid not null,
  target_owner_id uuid not null references public.profiles(id) on delete cascade,
  target_kind text not null check (target_kind in ('spot', 'profile')),
  reason text not null check (reason in ('harassment', 'hateOrAbuse', 'inappropriate', 'misinformation', 'spam', 'unsafeLocation', 'other')),
  details text not null default '',
  status text not null default 'open' check (status in ('open', 'reviewing', 'resolved', 'dismissed')),
  created_at timestamptz not null default now()
);

create or replace function public.set_updated_at()
returns trigger language plpgsql set search_path = '' as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger profiles_set_updated_at before update on public.profiles
for each row execute function public.set_updated_at();
create trigger spots_set_updated_at before update on public.spots
for each row execute function public.set_updated_at();
create trigger ratings_set_updated_at before update on public.ratings
for each row execute function public.set_updated_at();
create trigger trips_set_updated_at before update on public.trips
for each row execute function public.set_updated_at();
create trigger trip_stops_set_updated_at before update on public.trip_stops
for each row execute function public.set_updated_at();

alter table public.profiles enable row level security;
alter table public.spots enable row level security;
alter table public.likes enable row level security;
alter table public.saves enable row level security;
alter table public.ratings enable row level security;
alter table public.trips enable row level security;
alter table public.trip_stops enable row level security;
alter table public.interactions enable row level security;
alter table public.user_blocks enable row level security;
alter table public.reports enable row level security;

revoke all on all tables in schema public from anon, authenticated;
grant select on public.profiles, public.spots, public.ratings to anon, authenticated;
grant insert, update, delete on public.profiles, public.spots, public.ratings to authenticated;
grant select, insert, update, delete on public.likes, public.saves, public.trips, public.trip_stops, public.interactions, public.user_blocks to authenticated;
grant insert on public.reports to authenticated;

create policy profiles_public_read on public.profiles for select to anon, authenticated using (true);
create policy profiles_own_insert on public.profiles for insert to authenticated with check (auth.uid() = id);
create policy profiles_own_update on public.profiles for update to authenticated using (auth.uid() = id) with check (auth.uid() = id);
create policy profiles_own_delete on public.profiles for delete to authenticated using (auth.uid() = id);

create policy spots_public_read on public.spots for select to anon, authenticated using (true);
create policy spots_own_insert on public.spots for insert to authenticated with check (auth.uid() = owner_id);
create policy spots_own_update on public.spots for update to authenticated using (auth.uid() = owner_id) with check (auth.uid() = owner_id);
create policy spots_own_delete on public.spots for delete to authenticated using (auth.uid() = owner_id);

create policy likes_own_all on public.likes for all to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy saves_own_all on public.saves for all to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy ratings_public_read on public.ratings for select to anon, authenticated using (true);
create policy ratings_own_insert on public.ratings for insert to authenticated with check (auth.uid() = user_id);
create policy ratings_own_update on public.ratings for update to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy ratings_own_delete on public.ratings for delete to authenticated using (auth.uid() = user_id);
create policy trips_own_all on public.trips for all to authenticated using (auth.uid() = owner_id) with check (auth.uid() = owner_id);
create policy trip_stops_owner_all on public.trip_stops for all to authenticated
using (exists (select 1 from public.trips where trips.id = trip_stops.trip_id and trips.owner_id = auth.uid()))
with check (exists (select 1 from public.trips where trips.id = trip_stops.trip_id and trips.owner_id = auth.uid()));
create policy interactions_own_all on public.interactions for all to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy blocks_own_all on public.user_blocks for all to authenticated using (auth.uid() = blocker_id) with check (auth.uid() = blocker_id);
create policy reports_own_insert on public.reports for insert to authenticated with check (auth.uid() = reporter_id);

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('spot-photos', 'spot-photos', true, 26214400, array['image/jpeg', 'image/png', 'image/heic', 'image/heif'])
on conflict (id) do update set public = excluded.public, file_size_limit = excluded.file_size_limit, allowed_mime_types = excluded.allowed_mime_types;

create policy spot_photos_public_read on storage.objects for select to anon, authenticated
using (bucket_id = 'spot-photos');
create policy spot_photos_own_insert on storage.objects for insert to authenticated
with check (bucket_id = 'spot-photos' and (storage.foldername(name))[1] = auth.uid()::text);
create policy spot_photos_own_update on storage.objects for update to authenticated
using (bucket_id = 'spot-photos' and owner_id = auth.uid()::text)
with check (bucket_id = 'spot-photos' and (storage.foldername(name))[1] = auth.uid()::text);
create policy spot_photos_own_delete on storage.objects for delete to authenticated
using (bucket_id = 'spot-photos' and owner_id = auth.uid()::text);

create or replace function public.delete_my_account()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  caller uuid := auth.uid();
begin
  if caller is null then
    raise exception 'Authentication required';
  end if;
  delete from auth.users where id = caller;
end;
$$;
revoke all on function public.delete_my_account() from public, anon;
grant execute on function public.delete_my_account() to authenticated;
