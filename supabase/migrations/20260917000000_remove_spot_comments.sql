-- The first deployed community migration included both comments and reviews.
-- Product direction now keeps one clear interaction: written reviews.
drop table if exists public.spot_comments;

alter table public.reports drop constraint if exists reports_target_kind_check;
alter table public.reports add constraint reports_target_kind_check
check (target_kind in ('spot', 'profile', 'review'));
