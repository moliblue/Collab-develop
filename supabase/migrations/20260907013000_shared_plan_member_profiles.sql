create or replace function public.shares_travel_plan(target_user uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select target_user = auth.uid()
    or exists (
      select 1
      from public.plan_members target
      join public.plan_members viewer
        on viewer.plan_id = target.plan_id
      where target.user_id = target_user
        and viewer.user_id = auth.uid()
    );
$$;

revoke all on function public.shares_travel_plan(uuid) from public;
grant execute on function public.shares_travel_plan(uuid) to authenticated;
grant execute on function public.shares_travel_plan(uuid) to service_role;

drop policy if exists "plan members read shared profiles" on public.profiles;
create policy "plan members read shared profiles"
on public.profiles
for select
to authenticated
using (public.shares_travel_plan(id));
