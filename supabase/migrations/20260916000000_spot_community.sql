-- Community conversations and written reviews. Access follows the parent spot,
-- so Circle-only content is never discoverable outside its current membership.

alter table public.ratings
  add column review_body text not null default '',
  add constraint ratings_review_body_valid check (
    review_body = btrim(review_body)
    and (review_body = '' or char_length(review_body) between 3 and 2000)
  );

create table public.spot_comments (
  id uuid primary key default gen_random_uuid(),
  spot_id uuid not null references public.spots(id) on delete cascade,
  author_id uuid not null references public.profiles(id) on delete cascade,
  body text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint spot_comments_body_valid check (
    body = btrim(body) and char_length(body) between 1 and 1000
  )
);
create index spot_comments_spot_created_idx on public.spot_comments (spot_id, created_at desc, id desc);
create index spot_comments_author_idx on public.spot_comments (author_id);

create trigger spot_comments_set_updated_at before update on public.spot_comments
for each row execute function public.set_updated_at();

alter table public.spot_comments enable row level security;
revoke all on public.spot_comments from anon, authenticated;
grant select on public.spot_comments to anon, authenticated;
grant insert, update, delete on public.spot_comments to authenticated;

create policy spot_comments_anon_public_read on public.spot_comments for select to anon
using (exists (
  select 1 from public.spots
  where spots.id = spot_comments.spot_id and spots.is_public
));
create policy spot_comments_permitted_read on public.spot_comments for select to authenticated
using (exists (select 1 from public.spots where spots.id = spot_comments.spot_id));
create policy spot_comments_own_insert on public.spot_comments for insert to authenticated
with check (
  auth.uid() = author_id
  and exists (select 1 from public.spots where spots.id = spot_comments.spot_id)
);
create policy spot_comments_own_update on public.spot_comments for update to authenticated
using (auth.uid() = author_id)
with check (
  auth.uid() = author_id
  and exists (select 1 from public.spots where spots.id = spot_comments.spot_id)
);
create policy spot_comments_own_delete on public.spot_comments for delete to authenticated
using (auth.uid() = author_id);

-- Rating writes previously checked identity only. Also require visibility of the
-- parent spot, preventing writes to a private spot whose UUID was leaked.
drop policy ratings_own_insert on public.ratings;
drop policy ratings_own_update on public.ratings;
create policy ratings_own_insert on public.ratings for insert to authenticated
with check (
  auth.uid() = user_id
  and exists (select 1 from public.spots where spots.id = ratings.spot_id)
);
create policy ratings_own_update on public.ratings for update to authenticated
using (auth.uid() = user_id)
with check (
  auth.uid() = user_id
  and exists (select 1 from public.spots where spots.id = ratings.spot_id)
);

alter table public.reports drop constraint reports_target_kind_check;
alter table public.reports add constraint reports_target_kind_check
check (target_kind in ('spot', 'profile', 'comment', 'review'));

drop policy reports_own_insert on public.reports;
create policy reports_own_insert on public.reports for insert to authenticated
with check (
  auth.uid() = reporter_id
  and (
    (target_kind = 'spot' and exists (
      select 1 from public.spots where spots.id = reports.target_id and spots.owner_id = reports.target_owner_id
    ))
    or (target_kind = 'profile' and target_id = target_owner_id and exists (
      select 1 from public.profiles where profiles.id = reports.target_owner_id
    ))
    or (target_kind = 'comment' and exists (
      select 1 from public.spot_comments
      where spot_comments.id = reports.target_id and spot_comments.author_id = reports.target_owner_id
    ))
    or (target_kind = 'review' and exists (
      select 1 from public.ratings
      where ratings.id = reports.target_id and ratings.user_id = reports.target_owner_id
    ))
  )
);
