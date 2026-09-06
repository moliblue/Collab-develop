-- Persist the selected Malaysian regions so plan cards can render a stable,
-- deterministic cover. This migration is limited to Collaborative Planner.

alter table public.travel_plans
  add column if not exists trip_regions text[] not null default '{}',
  add column if not exists primary_region text;

alter table public.travel_plans
  drop constraint if exists travel_plans_primary_region_check;

alter table public.travel_plans
  add constraint travel_plans_primary_region_check
  check (
    primary_region is null or primary_region = any (array[
      'Johor',
      'Kedah',
      'Kelantan',
      'Melaka',
      'Negeri Sembilan',
      'Pahang',
      'Penang',
      'Perak',
      'Perlis',
      'Sabah',
      'Sarawak',
      'Selangor',
      'Terengganu',
      'Kuala Lumpur',
      'Putrajaya',
      'Labuan'
    ])
  );
