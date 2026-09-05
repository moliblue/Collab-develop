begin;

-- Plan module only: optimistic concurrency and member display data.
alter table public.travel_plans
  add column if not exists revision bigint not null default 0;

alter table public.plan_members
  add column if not exists display_name text;

create or replace function public.claim_plan_revision(
  target_plan uuid,
  expected_revision bigint
) returns bigint
language plpgsql
security definer
set search_path = public
as $$
declare
  next_revision bigint;
begin
  if not public.is_plan_member(target_plan) then
    raise exception 'plan access denied';
  end if;

  update public.travel_plans
  set revision = revision + 1,
      updated_at = now()
  where id = target_plan
    and revision = expected_revision
  returning revision into next_revision;

  return next_revision;
end;
$$;

create or replace function public.leave_travel_plan(
  target_plan uuid,
  new_owner uuid default null
) returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  current_owner uuid;
begin
  if auth.uid() is null then
    raise exception 'authentication required';
  end if;

  select owner_id
  into current_owner
  from public.travel_plans
  where id = target_plan;

  if current_owner is null or not public.is_plan_member(target_plan) then
    raise exception 'plan access denied';
  end if;

  if current_owner = auth.uid() then
    if new_owner is null or not exists (
      select 1
      from public.plan_members
      where plan_id = target_plan
        and user_id = new_owner
        and role = 'admin'
    ) then
      raise exception 'transfer admin rights before leaving';
    end if;

    update public.travel_plans
    set owner_id = new_owner,
        revision = revision + 1,
        updated_at = now()
    where id = target_plan;
  end if;

  delete from public.plan_members
  where plan_id = target_plan
    and user_id = auth.uid();
end;
$$;

revoke all on function public.claim_plan_revision(uuid, bigint) from public, anon;
revoke all on function public.leave_travel_plan(uuid, uuid) from public, anon;
grant execute on function public.claim_plan_revision(uuid, bigint) to authenticated;
grant execute on function public.leave_travel_plan(uuid, uuid) to authenticated;

drop policy if exists "owners create plans" on public.travel_plans;
create policy "owners create plans"
  on public.travel_plans
  for insert
  to authenticated
  with check (owner_id = auth.uid());

-- Owners must be able to read the row returned by their own insert before the
-- owner-membership trigger is visible to PostgREST's representation query.
drop policy if exists "members read plans" on public.travel_plans;
create policy "members read plans"
  on public.travel_plans
  for select
  to authenticated
  using (owner_id = auth.uid() or public.is_plan_member(id));

drop policy if exists "admins update plans" on public.travel_plans;
create policy "admins update plans"
  on public.travel_plans
  for update
  to authenticated
  using (owner_id = auth.uid() or public.is_plan_admin(id))
  with check (owner_id = auth.uid() or public.is_plan_admin(id));

drop policy if exists "admins delete plans" on public.travel_plans;
create policy "admins delete plans"
  on public.travel_plans
  for delete
  to authenticated
  using (owner_id = auth.uid() or public.is_plan_admin(id));

-- Realtime is enabled only for Plan module tables.
do $$
begin
  alter publication supabase_realtime add table public.travel_plans;
exception when duplicate_object then null;
end;
$$;

do $$
begin
  alter publication supabase_realtime add table public.plan_days;
exception when duplicate_object then null;
end;
$$;

do $$
begin
  alter publication supabase_realtime add table public.itinerary_cards;
exception when duplicate_object then null;
end;
$$;

do $$
begin
  alter publication supabase_realtime add table public.plan_members;
exception when duplicate_object then null;
end;
$$;

commit;
