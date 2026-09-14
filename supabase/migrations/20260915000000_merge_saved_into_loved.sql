-- Loved is the single collection concept. Preserve every former Saved spot as a
-- Like, preserve visit history separately, then remove the obsolete saves table.
insert into public.likes (user_id, spot_id, created_at)
select user_id, spot_id, created_at
from public.saves
where list = 'saved'
on conflict (user_id, spot_id) do nothing;

create table public.been_there (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  spot_id uuid not null references public.spots(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (user_id, spot_id)
);

insert into public.been_there (id, user_id, spot_id, created_at)
select id, user_id, spot_id, created_at
from public.saves
where list = 'beenThere'
on conflict (user_id, spot_id) do nothing;

alter table public.been_there enable row level security;
grant select, insert, update, delete on public.been_there to authenticated;
create policy been_there_own_all on public.been_there for all to authenticated
using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop table public.saves;

delete from public.interactions where event = 'save';
alter table public.interactions drop constraint interactions_event_check;
alter table public.interactions add constraint interactions_event_check
check (event in ('view', 'like', 'dismiss'));

-- Keep free-form tags canonical even when a future client writes directly.
create extension if not exists unaccent with schema extensions;

create or replace function public.normalize_spot_tags()
returns trigger language plpgsql set search_path = '' as $$
begin
  select coalesce(array_agg(distinct normalized order by normalized), '{}')
  into new.tags
  from (
    select trim(both '-' from regexp_replace(lower(extensions.unaccent(trim(both '#' from value))), '[^a-z0-9]+', '-', 'g')) as normalized
    from unnest(new.tags) as value
  ) values_normalized
  where normalized <> '';
  return new;
end;
$$;

create trigger spots_normalize_tags before insert or update of tags on public.spots
for each row execute function public.normalize_spot_tags();

update public.spots set tags = tags;

create or replace function public.normalize_profile_tags()
returns trigger language plpgsql set search_path = '' as $$
begin
  select coalesce(array_agg(distinct normalized order by normalized), '{}')
  into new.preferred_tags
  from (
    select trim(both '-' from regexp_replace(lower(extensions.unaccent(trim(both '#' from value))), '[^a-z0-9]+', '-', 'g')) as normalized
    from unnest(new.preferred_tags) as value
  ) values_normalized
  where normalized <> '';
  return new;
end;
$$;

create trigger profiles_normalize_tags before insert or update of preferred_tags on public.profiles
for each row execute function public.normalize_profile_tags();

update public.profiles set preferred_tags = preferred_tags;
