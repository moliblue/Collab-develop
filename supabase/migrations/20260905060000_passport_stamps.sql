-- Destination passport stamps are earned from verified UC102 arrivals.
-- One traveller can earn each destination stamp only once.

create table if not exists public.user_passport_stamps (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  destination_id uuid not null references public.destinations(id) on delete cascade,
  arrival_verification_id uuid references public.arrival_verifications(id)
    on delete set null,
  earned_at timestamptz not null default now(),
  unique (user_id, destination_id)
);

create index if not exists user_passport_stamps_user_earned_idx
on public.user_passport_stamps (user_id, earned_at desc);

alter table public.user_passport_stamps enable row level security;

drop policy if exists "Users can view own passport stamps"
on public.user_passport_stamps;

create policy "Users can view own passport stamps"
on public.user_passport_stamps for select to authenticated
using (user_id = auth.uid());

grant select on public.user_passport_stamps to authenticated;

-- Preserve stamps for destinations that were verified before this migration.
insert into public.user_passport_stamps (
  user_id,
  destination_id,
  arrival_verification_id,
  earned_at
)
select distinct on (participant.user_id, journey.destination_id)
  participant.user_id,
  journey.destination_id,
  verification.id,
  verification.verified_at
from public.arrival_verifications verification
join public.journey_participants participant
  on participant.id = verification.participant_id
join public.mystery_journeys journey
  on journey.id = participant.journey_id
where verification.verification_status = 'verified'
order by
  participant.user_id,
  journey.destination_id,
  verification.verified_at
on conflict (user_id, destination_id) do nothing;

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
  passport_count integer;
  newly_unlocked_xp integer;
begin
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

  select count(*)::integer
  into first_shake_count
  from public.journey_participants participant
  join public.mystery_journeys journey on journey.id = participant.journey_id
  where participant.user_id = target_user_id
    and (journey.mode = 'solo' or participant.shaken_at is not null);

  select count(*)::integer
  into passport_count
  from public.user_passport_stamps
  where user_id = target_user_id;

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

  insert into public.user_achievements (
    user_id,
    achievement_id,
    progress,
    unlocked_at
  )
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

create or replace function public.award_passport_stamp_after_arrival()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  awarded_user_id uuid;
begin
  if new.verification_status <> 'verified' then
    return new;
  end if;

  insert into public.user_passport_stamps (
    user_id,
    destination_id,
    arrival_verification_id,
    earned_at
  )
  select
    participant.user_id,
    journey.destination_id,
    new.id,
    new.verified_at
  from public.journey_participants participant
  join public.mystery_journeys journey
    on journey.id = participant.journey_id
  where participant.id = new.participant_id
  on conflict (user_id, destination_id) do nothing
  returning user_id into awarded_user_id;

  if awarded_user_id is not null then
    perform public.sync_user_achievements(awarded_user_id);
  end if;
  return new;
end;
$$;

revoke all on function public.award_passport_stamp_after_arrival()
from public;

drop trigger if exists award_passport_stamp_after_arrival
on public.arrival_verifications;

create trigger award_passport_stamp_after_arrival
after insert on public.arrival_verifications
for each row
execute function public.award_passport_stamp_after_arrival();

-- Re-evaluate users who received a historical backfilled stamp.
do $$
declare
  stamp_owner record;
begin
  for stamp_owner in
    select distinct user_id from public.user_passport_stamps
  loop
    perform public.sync_user_achievements(stamp_owner.user_id);
  end loop;
end;
$$;
