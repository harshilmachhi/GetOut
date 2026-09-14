begin;

select plan(8);

insert into auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
values
  ('00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000001', 'authenticated', 'authenticated', 'circle-owner@example.test', '', now(), '{}', '{}', now(), now()),
  ('00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000002', 'authenticated', 'authenticated', 'circle-member@example.test', '', now(), '{}', '{}', now(), now()),
  ('00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000003', 'authenticated', 'authenticated', 'circle-outsider@example.test', '', now(), '{}', '{}', now(), now());

insert into public.profiles (id, username, display_name)
values
  ('00000000-0000-0000-0000-000000000001', 'circle_owner', 'Circle Owner'),
  ('00000000-0000-0000-0000-000000000002', 'circle_member', 'Circle Member'),
  ('00000000-0000-0000-0000-000000000003', 'circle_outsider', 'Circle Outsider');

insert into public.circles (id, owner_id, name)
values ('10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001', 'Test Circle');
insert into public.circle_members (circle_id, user_id)
values ('10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000002');

insert into public.spots (id, owner_id, title, latitude, longitude, category, is_public)
values
  ('20000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001', 'Public test spot', 43.65, -79.38, 'views', true),
  ('20000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000001', 'Private test spot', 43.66, -79.39, 'views', false);
insert into public.spot_circles (spot_id, circle_id, shared_by)
values ('20000000-0000-0000-0000-000000000002', '10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001');

set local role anon;
select is((select count(*) from public.spots), 1::bigint, 'anonymous users see only public spots');
select is((select count(*) from public.spots where not is_public), 0::bigint, 'anonymous users cannot read private coordinates');
reset role;

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000000003","role":"authenticated"}', true);
select is((select count(*) from public.spots), 1::bigint, 'non-members see only public spots');
select is((select count(*) from public.circles), 0::bigint, 'non-members cannot discover Circles');
select is((select count(*) from public.circle_members), 0::bigint, 'non-members cannot enumerate membership');

select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000000002","role":"authenticated"}', true);
select is((select count(*) from public.spots), 2::bigint, 'members see public and Circle spots');
select is((select count(*) from public.circle_members), 2::bigint, 'members can see their Circle roster');

select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000000001","role":"authenticated"}', true);
create temporary table test_circle_invite(token text) on commit drop;
insert into test_circle_invite select public.create_circle_invite('10000000-0000-0000-0000-000000000001');
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000000003","role":"authenticated"}', true);
select lives_ok(
  format('select public.accept_circle_invite(%L)', (select token from test_circle_invite)),
  'a valid signed-in invite recipient can join'
);

select * from finish();
rollback;
