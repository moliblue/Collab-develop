-- Rebalance the achievement catalogue and connect First Shake to the existing
-- Mystery Journey participant events without changing the journey client code.

insert into public.achievements
  (code, name, description, rarity, xp_reward, icon_code,
   requirement_type, requirement_value, sort_order)
values
  ('FIRST_SHAKE', 'First Shake',
   'Start your first Mystery Journey with a successful shake.',
   'Common', 500, 98467, 'first_shake', 1, 1),
  ('HERITAGE_FIRST_STEP', 'First Footprint',
   'Complete your first verified Malaysian heritage journey.',
   'Common', 100, 93049, 'completed_journeys', 1, 2),
  ('LOCAL_TRAIL_SUPPORTER', 'Mystery Explorer',
   'Complete 3 verified Mystery Journeys.',
   'Common', 250, 93995, 'completed_journeys', 3, 3),
  ('HERITAGE_GUARDIAN', 'Heritage Guardian',
   'Complete 5 verified journeys and keep heritage discovery alive.',
   'Rare', 500, 91097, 'completed_journeys', 5, 4),
  ('MASTER_PATHFINDER', 'Master Pathfinder',
   'Complete 10 verified Mystery Journeys.',
   'Legendary', 1000, 98304, 'completed_journeys', 10, 5),
  ('COMMUNITY_EXPLORER', 'Better Together',
   'Complete a Mystery Journey together with a group.',
   'Common', 150, 98367, 'completed_group_journeys', 1, 6),
  ('TEAM_TRAILBLAZER', 'Team Trailblazer',
   'Complete 3 Mystery Journeys together with a group.',
   'Rare', 350, 98303, 'completed_group_journeys', 3, 7),
  ('PASSPORT_COLLECTOR', 'Passport Collector',
   'Collect 5 unique destination passport stamps.',
   'Epic', 500, 98464, 'passport_stamps', 5, 8)
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
  first_shake_count integer;
  passport_count integer := 0;
  newly_unlocked_xp integer;
begin
  -- Serialize rewards for this profile so achievement XP is only added once.
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

  -- A solo participant is created by the existing successful-shake flow. A
  -- group participant qualifies only after the existing shaken_at update.
  select count(*)::integer
  into first_shake_count
  from public.journey_participants participant
  join public.mystery_journeys journey on journey.id = participant.journey_id
  where participant.user_id = target_user_id
    and (journey.mode = 'solo' or participant.shaken_at is not null);

  -- Passport stamps are intentionally connected in the later passport phase.
  -- Keeping this at zero makes the catalogue visible without false unlocks.
  passport_count := 0;

  select coalesce(sum(achievement.xp_reward), 0)::integer
  into newly_unlocked_xp
  from public.achievements achievement
  left join public.user_achievements earned
    on earned.achievement_id = achievement.id
   and earned.user_id = target_user_id
  where earned.unlocked_at is null
    and case achievement.requirement_type
      when 'first_shake' then first_shake_count
      when 'completed_group_journeys' then completed_group_count
      when 'passport_stamps' then passport_count
      else completed_count
    end >= achievement.requirement_value;

  insert into public.user_achievements
    (user_id, achievement_id, progress, unlocked_at)
  select
    target_user_id,
    achievement.id,
    case achievement.requirement_type
      when 'first_shake' then first_shake_count
      when 'completed_group_journeys' then completed_group_count
      when 'passport_stamps' then passport_count
      else completed_count
    end,
    case when
      case achievement.requirement_type
        when 'first_shake' then first_shake_count
        when 'completed_group_journeys' then completed_group_count
        when 'passport_stamps' then passport_count
        else completed_count
      end >= achievement.requirement_value
      then now() else null end
  from public.achievements achievement
  on conflict (user_id, achievement_id) do update set
    progress = excluded.progress,
    unlocked_at = coalesce(
      public.user_achievements.unlocked_at,
      excluded.unlocked_at
    );

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

create or replace function public.sync_achievements_after_first_shake()
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

revoke all on function public.sync_achievements_after_first_shake()
from public;

drop trigger if exists sync_achievements_after_participant_insert
on public.journey_participants;

create trigger sync_achievements_after_participant_insert
after insert on public.journey_participants
for each row
execute function public.sync_achievements_after_first_shake();

drop trigger if exists sync_achievements_after_group_shake
on public.journey_participants;

create trigger sync_achievements_after_group_shake
after update of shaken_at on public.journey_participants
for each row
when (old.shaken_at is null and new.shaken_at is not null)
execute function public.sync_achievements_after_first_shake();
