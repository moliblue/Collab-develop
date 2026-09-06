alter table public.travel_plans
add column if not exists regions text[] not null default '{}';

comment on column public.travel_plans.regions is
  'Malaysian states or federal territories selected when creating the plan.';
