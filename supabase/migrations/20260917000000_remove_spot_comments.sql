-- The first deployed community migration included both comments and reviews.
-- Product direction now keeps one clear interaction: written reviews.
-- Remove the dependent policy before dropping its referenced table.
drop policy if exists reports_own_insert on public.reports;

drop table if exists public.spot_comments;

-- Comment reports have no remaining target once comments are removed.
delete from public.reports where target_kind = 'comment';

alter table public.reports drop constraint if exists reports_target_kind_check;
alter table public.reports add constraint reports_target_kind_check
check (target_kind in ('spot', 'profile', 'review'));

create policy reports_own_insert on public.reports for insert to authenticated
with check (
  auth.uid() = reporter_id
  and (
    (target_kind = 'spot' and exists (
      select 1 from public.spots
      where spots.id = reports.target_id
        and spots.owner_id = reports.target_owner_id
    ))
    or (target_kind = 'profile' and target_id = target_owner_id and exists (
      select 1 from public.profiles
      where profiles.id = reports.target_owner_id
    ))
    or (target_kind = 'review' and exists (
      select 1 from public.ratings
      where ratings.id = reports.target_id
        and ratings.user_id = reports.target_owner_id
    ))
  )
);
