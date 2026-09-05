begin;
create extension if not exists pgtap with schema extensions;
select plan(8);

insert into auth.users (id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
values
  ('10000000-0000-4000-8000-000000000001', 'authenticated', 'authenticated', 'owner@test.local', '', now(), now(), now()),
  ('10000000-0000-4000-8000-000000000002', 'authenticated', 'authenticated', 'member@test.local', '', now(), now(), now()),
  ('10000000-0000-4000-8000-000000000003', 'authenticated', 'authenticated', 'outsider@test.local', '', now(), now(), now());

select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000001', true);
set local role authenticated;

insert into public.travel_plans (id, owner_id, name, start_date, end_date, invite_code)
values ('20000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000001', 'RLS test', '2026-09-10', '2026-09-10', 'RLS-TEST');
select is((select count(*)::integer from public.travel_plans where id='20000000-0000-4000-8000-000000000001'), 1, 'owner can create and read a plan');

insert into public.plan_members(plan_id,user_id,role) values ('20000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000002','member');
select is((select count(*)::integer from public.plan_members where plan_id='20000000-0000-4000-8000-000000000001'), 2, 'owner can add a member');

select set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000002', true);
select is((select count(*)::integer from public.travel_plans where id='20000000-0000-4000-8000-000000000001'), 1, 'member can read the shared plan');
insert into public.plan_days(id,plan_id,date,position) values ('30000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001','2026-09-10',0);
select is((select count(*)::integer from public.plan_days where plan_id='20000000-0000-4000-8000-000000000001'), 1, 'member can create a date tab');
insert into public.itinerary_cards(id,day_id,title,location,start_time,category,latitude,longitude,position) values ('40000000-0000-4000-8000-000000000001','30000000-0000-4000-8000-000000000001','Test','Kuala Lumpur','09:00','Sightseeing',3.139,101.6869,0);
select is((select count(*)::integer from public.itinerary_cards where day_id='30000000-0000-4000-8000-000000000001'), 1, 'member can create and read a card');
select throws_ok($$ delete from public.travel_plans where id='20000000-0000-4000-8000-000000000001' $$, '42501', null, 'member cannot delete the plan');

select set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000003', true);
select is((select count(*)::integer from public.travel_plans where id='20000000-0000-4000-8000-000000000001'), 0, 'outsider cannot read the plan');
select throws_ok($$ insert into public.plan_days(id,plan_id,date,position) values ('30000000-0000-4000-8000-000000000002','20000000-0000-4000-8000-000000000001','2026-09-11',1) $$, '42501', null, 'outsider cannot modify the plan');

select * from finish();
rollback;
