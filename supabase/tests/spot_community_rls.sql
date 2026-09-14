begin;

select plan(12);

insert into auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
values
  ('00000000-0000-0000-0000-000000000000', '30000000-0000-0000-0000-000000000001', 'authenticated', 'authenticated', 'community-owner@example.test', '', now(), '{}', '{}', now(), now()),
  ('00000000-0000-0000-0000-000000000000', '30000000-0000-0000-0000-000000000002', 'authenticated', 'authenticated', 'community-member@example.test', '', now(), '{}', '{}', now(), now()),
  ('00000000-0000-0000-0000-000000000000', '30000000-0000-0000-0000-000000000003', 'authenticated', 'authenticated', 'community-outsider@example.test', '', now(), '{}', '{}', now(), now());

insert into public.profiles (id, username, display_name)
values
  ('30000000-0000-0000-0000-000000000001', 'community_owner', 'Community Owner'),
  ('30000000-0000-0000-0000-000000000002', 'community_member', 'Community Member'),
  ('30000000-0000-0000-0000-000000000003', 'community_outside', 'Community Outsider');

insert into public.circles (id, owner_id, name)
values ('31000000-0000-0000-0000-000000000001', '30000000-0000-0000-0000-000000000001', 'Community Circle');
insert into public.circle_members (circle_id, user_id)
values ('31000000-0000-0000-0000-000000000001', '30000000-0000-0000-0000-000000000002');

insert into public.spots (id, owner_id, title, latitude, longitude, category, is_public)
values
  ('32000000-0000-0000-0000-000000000001', '30000000-0000-0000-0000-000000000001', 'Public community spot', 43.65, -79.38, 'views', true),
  ('32000000-0000-0000-0000-000000000002', '30000000-0000-0000-0000-000000000001', 'Private community spot', 43.66, -79.39, 'views', false);
insert into public.spot_circles (spot_id, circle_id, shared_by)
values ('32000000-0000-0000-0000-000000000002', '31000000-0000-0000-0000-000000000001', '30000000-0000-0000-0000-000000000001');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"30000000-0000-0000-0000-000000000002","role":"authenticated"}', true);
select lives_ok(
  $$insert into public.spot_comments (spot_id, author_id, body) values ('32000000-0000-0000-0000-000000000002', '30000000-0000-0000-0000-000000000002', 'A private Circle comment')$$,
  'Circle members can comment on private spots'
);
select lives_ok(
  $$insert into public.ratings (spot_id, user_id, stars, review_body) values ('32000000-0000-0000-0000-000000000002', '30000000-0000-0000-0000-000000000002', 5, 'A private Circle review')$$,
  'Circle members can review private spots'
);
select is((select count(*) from public.spot_comments where spot_id = '32000000-0000-0000-0000-000000000002'), 1::bigint, 'Circle members can read private comments');
select is((select count(*) from public.ratings where spot_id = '32000000-0000-0000-0000-000000000002' and review_body <> ''), 1::bigint, 'Circle members can read private reviews');

select set_config('request.jwt.claims', '{"sub":"30000000-0000-0000-0000-000000000003","role":"authenticated"}', true);
select is((select count(*) from public.spot_comments where spot_id = '32000000-0000-0000-0000-000000000002'), 0::bigint, 'Outsiders cannot read private comments');
select is((select count(*) from public.ratings where spot_id = '32000000-0000-0000-0000-000000000002'), 0::bigint, 'Outsiders cannot read private reviews');
select throws_matching(
  $$insert into public.spot_comments (spot_id, author_id, body) values ('32000000-0000-0000-0000-000000000002', '30000000-0000-0000-0000-000000000003', 'Leaked UUID comment')$$,
  '.*row-level security policy.*', 'Outsiders cannot comment on a private spot'
);
select throws_matching(
  $$insert into public.ratings (spot_id, user_id, stars, review_body) values ('32000000-0000-0000-0000-000000000002', '30000000-0000-0000-0000-000000000003', 1, 'Leaked UUID review')$$,
  '.*row-level security policy.*', 'Outsiders cannot review a private spot'
);
select lives_ok(
  $$insert into public.spot_comments (spot_id, author_id, body) values ('32000000-0000-0000-0000-000000000001', '30000000-0000-0000-0000-000000000003', 'A public comment')$$,
  'Signed-in users can comment on public spots'
);
select lives_ok(
  $$insert into public.ratings (spot_id, user_id, stars, review_body) values ('32000000-0000-0000-0000-000000000001', '30000000-0000-0000-0000-000000000003', 4, 'A public review')$$,
  'Signed-in users can review public spots'
);

reset role;
set local role anon;
select is((select count(*) from public.spot_comments), 1::bigint, 'Anonymous users see public comments only');
select is((select count(*) from public.ratings where review_body <> ''), 1::bigint, 'Anonymous users see public reviews only');

select * from finish();
rollback;
