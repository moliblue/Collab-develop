-- ExploreMY profile and heritage achievement support.
-- Login email remains in auth.users; public.profiles stores app profile data.

alter table public.profiles
  add column if not exists bio text not null default '',
  add column if not exists trips_completed integer not null default 0;

alter table public.profiles
  drop constraint if exists profiles_bio_length_check,
  drop constraint if exists profiles_trips_completed_check;

alter table public.profiles
  add constraint profiles_bio_length_check check (char_length(bio) <= 300),
  add constraint profiles_trips_completed_check check (trips_completed >= 0);

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, username, full_name)
  values (
    new.id,
    new.raw_user_meta_data ->> 'username',
    coalesce(
      new.raw_user_meta_data ->> 'full_name',
      new.raw_user_meta_data ->> 'display_name'
    )
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

update public.profiles p
set full_name = coalesce(
  p.full_name,
  u.raw_user_meta_data ->> 'full_name',
  u.raw_user_meta_data ->> 'display_name',
  split_part(u.email, '@', 1)
)
from auth.users u
where p.id = u.id and p.full_name is null;

create table if not exists public.achievements (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  name text not null,
  description text not null,
  rarity text not null default 'Common',
  xp_reward integer not null default 0 check (xp_reward >= 0),
  icon_code integer not null default 93401,
  requirement_type text not null,
  requirement_value integer not null check (requirement_value > 0),
  sort_order integer not null default 0,
  created_at timestamptz not null default now()
);

create table if not exists public.user_achievements (
  user_id uuid not null references auth.users(id) on delete cascade,
  achievement_id uuid not null references public.achievements(id) on delete cascade,
  progress integer not null default 0 check (progress >= 0),
  unlocked_at timestamptz,
  primary key (user_id, achievement_id)
);

alter table public.achievements enable row level security;
alter table public.user_achievements enable row level security;

drop policy if exists "Authenticated users can view achievements" on public.achievements;
create policy "Authenticated users can view achievements"
on public.achievements for select to authenticated using (true);

drop policy if exists "Users can view own achievements" on public.user_achievements;
create policy "Users can view own achievements"
on public.user_achievements for select to authenticated
using (user_id = auth.uid());

grant select on public.achievements to authenticated;
grant select on public.user_achievements to authenticated;

insert into public.achievements
  (code, name, description, rarity, xp_reward, icon_code,
   requirement_type, requirement_value, sort_order)
values
  ('HERITAGE_FIRST_STEP', 'Heritage First Step',
   'Complete your first verified Malaysian heritage journey.',
   'Common', 100, 93049, 'completed_journeys', 1, 1),
  ('LOCAL_TRAIL_SUPPORTER', 'Local Trail Supporter',
   'Complete 3 journeys that encourage sustainable local tourism.',
   'Rare', 250, 93995, 'completed_journeys', 3, 2),
  ('COMMUNITY_EXPLORER', 'Community Explorer',
   'Complete a Mystery Journey together with a group.',
   'Rare', 200, 98467, 'completed_group_journeys', 1, 3),
  ('HERITAGE_GUARDIAN', 'Heritage Guardian',
   'Complete 5 verified journeys and help keep heritage discovery alive.',
   'Legendary', 500, 91097, 'completed_journeys', 5, 4)
on conflict (code) do update set
  name = excluded.name,
  description = excluded.description,
  rarity = excluded.rarity,
  xp_reward = excluded.xp_reward,
  icon_code = excluded.icon_code,
  requirement_type = excluded.requirement_type,
  requirement_value = excluded.requirement_value,
  sort_order = excluded.sort_order;

create or replace function public.sync_user_achievements(target_user_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  completed_count integer;
  completed_group_count integer;
  newly_unlocked_xp integer;
begin
  -- Serialize rewards for this profile so badge XP cannot be added twice.
  perform 1
  from public.profiles
  where id = target_user_id
  for update;

  select count(*)::integer
  into completed_count
  from public.journey_participants
  where user_id = target_user_id and participant_status = 'completed';

  select count(*)::integer
  into completed_group_count
  from public.journey_participants participant
  join public.mystery_journeys journey on journey.id = participant.journey_id
  where participant.user_id = target_user_id
    and participant.participant_status = 'completed'
    and journey.mode = 'group';

  select coalesce(sum(achievement.xp_reward), 0)::integer
  into newly_unlocked_xp
  from public.achievements achievement
  left join public.user_achievements earned
    on earned.achievement_id = achievement.id
   and earned.user_id = target_user_id
  where earned.unlocked_at is null
    and case achievement.requirement_type
      when 'completed_group_journeys' then completed_group_count
      else completed_count
    end >= achievement.requirement_value;

  insert into public.user_achievements
    (user_id, achievement_id, progress, unlocked_at)
  select
    target_user_id,
    achievement.id,
    case achievement.requirement_type
      when 'completed_group_journeys' then completed_group_count
      else completed_count
    end,
    case when
      case achievement.requirement_type
        when 'completed_group_journeys' then completed_group_count
        else completed_count
      end >= achievement.requirement_value
      then now() else null end
  from public.achievements achievement
  on conflict (user_id, achievement_id) do update set
    progress = excluded.progress,
    unlocked_at = coalesce(public.user_achievements.unlocked_at, excluded.unlocked_at);

  update public.profiles
  set trips_completed = completed_count,
      xp = xp + newly_unlocked_xp,
      explorer_level = greatest(
        explorer_level,
        floor((xp + newly_unlocked_xp) / 500.0)::integer + 1
      ),
      updated_at = now()
  where id = target_user_id;
end;
$$;

revoke all on function public.sync_user_achievements(uuid) from public;

create or replace function public.evaluate_my_achievements()
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;
  perform public.sync_user_achievements(auth.uid());
end;
$$;

revoke all on function public.evaluate_my_achievements() from public;
grant execute on function public.evaluate_my_achievements() to authenticated;

create or replace function public.sync_achievements_after_journey_completion()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform public.sync_user_achievements(new.user_id);
  return new;
end;
$$;

revoke all on function public.sync_achievements_after_journey_completion()
from public;

drop trigger if exists sync_achievements_after_journey_completion
on public.journey_participants;

create trigger sync_achievements_after_journey_completion
after update of participant_status on public.journey_participants
for each row
when (
  old.participant_status is distinct from new.participant_status
  and new.participant_status = 'completed'
)
execute function public.sync_achievements_after_journey_completion();
