-- Written reviews reuse ratings so each person has one rating/review per spot.
-- Rating visibility follows the parent spot, including Circle membership.
alter table public.ratings
  add column review_body text not null default '',
  add constraint ratings_review_body_valid check (
    review_body = btrim(review_body)
    and (review_body = '' or char_length(review_body) between 3 and 2000)
  );

-- Require visibility of the parent spot on writes. This prevents a non-member
-- from reviewing a private spot even if its UUID is disclosed.
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
check (target_kind in ('spot', 'profile', 'review'));

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
    or (target_kind = 'review' and exists (
      select 1 from public.ratings
      where ratings.id = reports.target_id and ratings.user_id = reports.target_owner_id
    ))
  )
);
