SET local check_function_bodies = off;

CREATE TABLE "public"."arrival_verifications" (
  "id"                  uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "participant_id"      uuid                     NOT NULL,
  "latitude"            double precision         NOT NULL,
  "longitude"           double precision         NOT NULL,
  "distance_meters"     double precision,
  "verification_status" text                     NOT NULL,
  "verified_at"         timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT "arrival_verifications_pkey" PRIMARY KEY (id),
  CONSTRAINT "valid_arrival_distance" CHECK (((distance_meters IS NULL) OR (distance_meters >= (0)::double precision))),
  CONSTRAINT "valid_arrival_latitude" CHECK (((latitude >= ('-90'::integer)::double precision) AND (latitude <= (90)::double precision))),
  CONSTRAINT "valid_arrival_longitude" CHECK (((longitude >= ('-180'::integer)::double precision) AND (longitude <= (180)::double precision))),
  CONSTRAINT "valid_arrival_verification_status" CHECK ((verification_status = ANY (ARRAY['verified'::text, 'not_within_range'::text])))
);

ALTER TABLE "public"."arrival_verifications"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "public"."destination_clues" (
  "id"             uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "destination_id" uuid                     NOT NULL,
  "clue_type"      text                     NOT NULL,
  "clue_text"      text                     NOT NULL,
  "clue_order"     integer                  NOT NULL DEFAULT 1,
  "created_at"     timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT "destination_clues_destination_id_clue_type_clue_order_key" UNIQUE (destination_id, clue_type, clue_order),
  CONSTRAINT "destination_clues_pkey" PRIMARY KEY (id),
  CONSTRAINT "valid_clue_order" CHECK ((clue_order >= 1)),
  CONSTRAINT "valid_clue_type" CHECK ((clue_type = ANY (ARRAY['initial'::text, 'additional'::text])))
);

ALTER TABLE "public"."destination_clues"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "public"."destinations" (
  "id"          uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "name"        text                     NOT NULL,
  "category"    text                     NOT NULL,
  "latitude"    double precision         NOT NULL,
  "longitude"   double precision         NOT NULL,
  "address"     text                     NOT NULL,
  "description" text,
  "image_url"   text,
  "is_active"   boolean                  NOT NULL DEFAULT true,
  "created_at"  timestamp with time zone NOT NULL DEFAULT now(),
  "updated_at"  timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT "destinations_pkey" PRIMARY KEY (id),
  CONSTRAINT "valid_destination_category" CHECK ((category = ANY (ARRAY['culture'::text, 'history'::text, 'local_food'::text, 'art_streets'::text]))),
  CONSTRAINT "valid_latitude" CHECK (((latitude >= ('-90'::integer)::double precision) AND (latitude <= (90)::double precision))),
  CONSTRAINT "valid_longitude" CHECK (((longitude >= ('-180'::integer)::double precision) AND (longitude <= (180)::double precision)))
);

ALTER TABLE "public"."destinations"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "public"."group_action_votes" (
  "id"         uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "journey_id" uuid                     NOT NULL,
  "room_id"    uuid                     NOT NULL,
  "user_id"    uuid                     NOT NULL,
  "vote_type"  text                     NOT NULL,
  "vote_round" integer                  NOT NULL,
  "vote_yes"   boolean                  NOT NULL DEFAULT true,
  "created_at" timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT "group_action_votes_journey_id_vote_type_vote_round_user_id_key" UNIQUE (journey_id, vote_type, vote_round, user_id),
  CONSTRAINT "group_action_votes_pkey" PRIMARY KEY (id),
  CONSTRAINT "group_action_votes_vote_round_check" CHECK ((vote_round > 0)),
  CONSTRAINT "group_action_votes_vote_type_check" CHECK ((vote_type = ANY (ARRAY['hint'::text, 'route'::text])))
);

ALTER TABLE "public"."group_action_votes"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "public"."group_chat_messages" (
  "id"         uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "room_id"    uuid                     NOT NULL,
  "user_id"    uuid                     NOT NULL,
  "message"    text                     NOT NULL,
  "created_at" timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT "group_chat_messages_message_check" CHECK (((char_length(btrim(message)) >= 1) AND (char_length(btrim(message)) <= 500))),
  CONSTRAINT "group_chat_messages_pkey" PRIMARY KEY (id)
);

ALTER TABLE "public"."group_chat_messages"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "public"."group_room_members" (
  "id"            uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "room_id"       uuid                     NOT NULL,
  "user_id"       uuid                     NOT NULL,
  "role"          text                     NOT NULL DEFAULT 'member'::text,
  "member_status" text                     NOT NULL DEFAULT 'waiting'::text,
  "joined_at"     timestamp with time zone NOT NULL DEFAULT now(),
  "left_at"       timestamp with time zone,
  "is_ready"      boolean                  NOT NULL DEFAULT false,
  CONSTRAINT "group_room_members_pkey" PRIMARY KEY (id),
  CONSTRAINT "group_room_members_room_id_user_id_key" UNIQUE (room_id, user_id),
  CONSTRAINT "valid_group_member_role" CHECK ((role = ANY (ARRAY['host'::text, 'member'::text]))),
  CONSTRAINT "valid_group_member_status" CHECK ((member_status = ANY (ARRAY['waiting'::text, 'active'::text, 'left'::text])))
);

ALTER TABLE "public"."group_room_members"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "public"."group_rooms" (
  "id"              uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "host_user_id"    uuid                     NOT NULL,
  "journey_id"      uuid,
  "status"          text                     NOT NULL DEFAULT 'waiting'::text,
  "preference_mode" text                     NOT NULL,
  "host_latitude"   double precision,
  "host_longitude"  double precision,
  "created_at"      timestamp with time zone NOT NULL DEFAULT now(),
  "expires_at"      timestamp with time zone NOT NULL DEFAULT (now() + '24:00:00'::interval),
  "activated_at"    timestamp with time zone,
  "closed_at"       timestamp with time zone,
  "updated_at"      timestamp with time zone NOT NULL DEFAULT now(),
  "preferences"     jsonb,
  CONSTRAINT "group_rooms_pkey" PRIMARY KEY (id),
  CONSTRAINT "valid_group_host_latitude" CHECK (((host_latitude IS NULL) OR ((host_latitude >= ('-90'::integer)::double precision) AND (host_latitude <= (90)::double precision)))),
  CONSTRAINT "valid_group_host_longitude"
    CHECK (((host_longitude IS NULL) OR ((host_longitude >= ('-180'::integer)::double precision) AND (host_longitude <= (180)::double precision)))),
  CONSTRAINT "valid_group_preference_mode" CHECK ((preference_mode = ANY (ARRAY['saved_preferences'::text, 'edited_preferences'::text, 'surprise_me'::text]))),
  CONSTRAINT "valid_group_room_status" CHECK ((status = ANY (ARRAY['waiting'::text, 'active'::text, 'cancelled'::text, 'expired'::text, 'closed'::text]))),
  CONSTRAINT "valid_room_expiry" CHECK ((expires_at > created_at))
);

ALTER TABLE "public"."group_rooms"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "public"."itinerary_cards" (
  "id"               uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "day_id"           uuid                     NOT NULL,
  "title"            text                     NOT NULL,
  "location"         text                     NOT NULL,
  "start_time"       time without time zone   NOT NULL,
  "category"         text                     NOT NULL DEFAULT 'Sightseeing'::text,
  "description"      text                     NOT NULL DEFAULT ''::text,
  "latitude"         double precision         NOT NULL,
  "longitude"        double precision         NOT NULL,
  "position"         integer                  NOT NULL DEFAULT 0,
  "route_distance_m" double precision,
  "route_duration_s" double precision,
  "route_geometry"   jsonb,
  "created_at"       timestamp with time zone NOT NULL DEFAULT now(),
  "updated_at"       timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT "itinerary_cards_latitude_check" CHECK (((latitude >= ('-90'::integer)::double precision) AND (latitude <= (90)::double precision))),
  CONSTRAINT "itinerary_cards_location_check" CHECK ((char_length(TRIM(BOTH FROM location)) > 0)),
  CONSTRAINT "itinerary_cards_longitude_check" CHECK (((longitude >= ('-180'::integer)::double precision) AND (longitude <= (180)::double precision))),
  CONSTRAINT "itinerary_cards_pkey" PRIMARY KEY (id),
  CONSTRAINT "itinerary_cards_position_check" CHECK (("position" >= 0)),
  CONSTRAINT "itinerary_cards_title_check" CHECK ((char_length(TRIM(BOTH FROM title)) > 0))
);

ALTER TABLE "public"."itinerary_cards"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "public"."journey_participants" (
  "id"                 uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "journey_id"         uuid                     NOT NULL,
  "user_id"            uuid                     NOT NULL,
  "participant_status" text                     NOT NULL DEFAULT 'active'::text,
  "joined_at"          timestamp with time zone NOT NULL DEFAULT now(),
  "completed_at"       timestamp with time zone,
  "cancelled_at"       timestamp with time zone,
  "created_at"         timestamp with time zone NOT NULL DEFAULT now(),
  "updated_at"         timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT "journey_participants_journey_id_user_id_key" UNIQUE (journey_id, user_id),
  CONSTRAINT "journey_participants_pkey" PRIMARY KEY (id),
  CONSTRAINT "valid_participant_status" CHECK ((participant_status = ANY (ARRAY['active'::text, 'completed'::text, 'cancelled'::text])))
);

ALTER TABLE "public"."journey_participants"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "public"."journey_preference_categories" (
  "id"         uuid NOT NULL DEFAULT gen_random_uuid(),
  "journey_id" uuid NOT NULL,
  "category"   text NOT NULL,
  CONSTRAINT "journey_preference_categories_journey_id_category_key" UNIQUE (journey_id, category),
  CONSTRAINT "journey_preference_categories_pkey" PRIMARY KEY (id),
  CONSTRAINT "valid_journey_preference_category" CHECK ((category = ANY (ARRAY['culture'::text, 'history'::text, 'local_food'::text, 'art_streets'::text])))
);

ALTER TABLE "public"."journey_preference_categories"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "public"."mystery_journeys" (
  "id"                   uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "mode"                 text                     NOT NULL,
  "destination_id"       uuid                     NOT NULL,
  "initial_clue_id"      uuid                     NOT NULL,
  "selection_mode"       text                     NOT NULL,
  "discovery_radius_km"  integer                  NOT NULL,
  "status"               text                     NOT NULL DEFAULT 'active'::text,
  "exact_route_revealed" boolean                  NOT NULL DEFAULT false,
  "started_at"           timestamp with time zone NOT NULL DEFAULT now(),
  "completed_at"         timestamp with time zone,
  "cancelled_at"         timestamp with time zone,
  "created_at"           timestamp with time zone NOT NULL DEFAULT now(),
  "updated_at"           timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT "mystery_journeys_pkey" PRIMARY KEY (id),
  CONSTRAINT "valid_journey_mode" CHECK ((mode = ANY (ARRAY['solo'::text, 'group'::text]))),
  CONSTRAINT "valid_journey_radius" CHECK (((discovery_radius_km >= 5) AND (discovery_radius_km <= 50))),
  CONSTRAINT "valid_journey_status" CHECK ((status = ANY (ARRAY['active'::text, 'completed'::text, 'cancelled'::text]))),
  CONSTRAINT "valid_selection_mode" CHECK ((selection_mode = ANY (ARRAY['saved_preferences'::text, 'edited_preferences'::text, 'surprise_me'::text]))),
  "created_by_user_id"   uuid                     DEFAULT auth.uid()
);

ALTER TABLE "public"."mystery_journeys"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "public"."participant_hint_unlocks" (
  "id"             uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "participant_id" uuid                     NOT NULL,
  "clue_id"        uuid                     NOT NULL,
  "unlocked_at"    timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT "participant_hint_unlocks_participant_id_clue_id_key" UNIQUE (participant_id, clue_id),
  CONSTRAINT "participant_hint_unlocks_pkey" PRIMARY KEY (id)
);

ALTER TABLE "public"."participant_hint_unlocks"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "public"."plan_days" (
  "id"       uuid    NOT NULL DEFAULT gen_random_uuid(),
  "plan_id"  uuid    NOT NULL,
  "date"     date    NOT NULL,
  "position" integer NOT NULL DEFAULT 0,
  CONSTRAINT "plan_days_pkey" PRIMARY KEY (id),
  CONSTRAINT "plan_days_plan_id_date_key" UNIQUE (plan_id, date),
  CONSTRAINT "plan_days_position_check" CHECK (("position" >= 0))
);

ALTER TABLE "public"."plan_days"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "public"."plan_members" (
  "plan_id"   uuid                     NOT NULL,
  "user_id"   uuid                     NOT NULL,
  "role"      text                     NOT NULL DEFAULT 'member'::text,
  "joined_at" timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT "plan_members_pkey" PRIMARY KEY (plan_id, user_id),
  CONSTRAINT "plan_members_role_check" CHECK ((role = ANY (ARRAY['admin'::text, 'member'::text])))
);

ALTER TABLE "public"."plan_members"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "public"."profiles" (
  "id"             uuid                     NOT NULL,
  "username"       text,
  "full_name"      text,
  "avatar_url"     text,
  "explorer_level" integer                  NOT NULL DEFAULT 1,
  "xp"             integer                  NOT NULL DEFAULT 0,
  "streak_days"    integer                  NOT NULL DEFAULT 0,
  "created_at"     timestamp with time zone NOT NULL DEFAULT now(),
  "updated_at"     timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT "profiles_pkey" PRIMARY KEY (id),
  CONSTRAINT "profiles_username_key" UNIQUE (username)
);

ALTER TABLE "public"."profiles"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "public"."travel_plans" (
  "id"          uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "owner_id"    uuid                     NOT NULL,
  "name"        text                     NOT NULL,
  "start_date"  date                     NOT NULL,
  "end_date"    date                     NOT NULL,
  "invite_code" text                     NOT NULL,
  "created_at"  timestamp with time zone NOT NULL DEFAULT now(),
  "updated_at"  timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT "travel_plans_invite_code_key" UNIQUE (invite_code),
  CONSTRAINT "travel_plans_name_check" CHECK (((char_length(TRIM(BOTH FROM name)) >= 1) AND (char_length(TRIM(BOTH FROM name)) <= 100))),
  CONSTRAINT "travel_plans_pkey" PRIMARY KEY (id),
  CONSTRAINT "valid_plan_dates" CHECK ((end_date >= start_date))
);

ALTER TABLE "public"."travel_plans"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "public"."user_preference_categories" (
  "id"            uuid NOT NULL DEFAULT gen_random_uuid(),
  "preference_id" uuid NOT NULL,
  "category"      text NOT NULL,
  CONSTRAINT "user_preference_categories_pkey" PRIMARY KEY (id),
  CONSTRAINT "user_preference_categories_preference_id_category_key" UNIQUE (preference_id, category),
  CONSTRAINT "valid_preference_category" CHECK ((category = ANY (ARRAY['culture'::text, 'history'::text, 'local_food'::text, 'art_streets'::text])))
);

ALTER TABLE "public"."user_preference_categories"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "public"."user_preferences" (
  "id"                  uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "user_id"             uuid                     NOT NULL,
  "discovery_radius_km" integer                  NOT NULL DEFAULT 15,
  "created_at"          timestamp with time zone NOT NULL DEFAULT now(),
  "updated_at"          timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT "discovery_radius_range" CHECK (((discovery_radius_km >= 5) AND (discovery_radius_km <= 50))),
  CONSTRAINT "user_preferences_pkey" PRIMARY KEY (id),
  CONSTRAINT "user_preferences_user_id_key" UNIQUE (user_id)
);

ALTER TABLE "public"."user_preferences"
  ENABLE ROW LEVEL SECURITY;

CREATE OR REPLACE FUNCTION public.activate_group_room (
  p_room_id      uuid,
  p_journey_id   uuid,
  p_activated_at timestamp with time zone,
  p_expires_at   timestamp with time zone
)
  RETURNS uuid
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public', 'pg_temp'
  AS $function$
declare
  v_user_id uuid := auth.uid();
  v_room public.group_rooms%rowtype;
  v_member_count integer;
  v_unready_count integer;
begin
  if v_user_id is null then
    raise exception 'Authentication is required.';
  end if;

  select *
  into v_room
  from public.group_rooms
  where id = p_room_id
  for update;

  if not found
     or v_room.host_user_id <> v_user_id
     or v_room.status <> 'waiting'
     or v_room.journey_id is not null then
    raise exception 'Only the host of a waiting room can start the Group Journey.';
  end if;

  select
    count(*)::integer,
    count(*) filter (where membership.is_ready is not true)::integer
  into v_member_count, v_unready_count
  from public.group_room_members membership
  where membership.room_id = p_room_id
    and membership.member_status <> 'left';

  if v_member_count < 2 then
    raise exception 'At least two travellers are required to start.';
  end if;

  if v_unready_count > 0 then
    raise exception 'Everyone must be ready before starting.';
  end if;

  if not exists (
    select 1
    from public.mystery_journeys journey
    where journey.id = p_journey_id
      and journey.mode = 'group'
      and journey.status = 'active'
  ) then
    raise exception 'The shared Group Journey is not valid.';
  end if;

  update public.group_rooms
  set journey_id = p_journey_id,
      status = 'active',
      activated_at = p_activated_at,
      expires_at = p_expires_at,
      updated_at = now()
  where id = p_room_id;

  update public.group_room_members
  set member_status = 'active',
      is_ready = false
  where room_id = p_room_id
    and member_status = 'waiting';

  return p_room_id;
end;
$function$;

CREATE OR REPLACE FUNCTION public.add_group_test_member (
  p_room_id       uuid,
  p_test_username text
)
  RETURNS uuid
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public', 'pg_temp'
  AS $function$
declare
  v_host_id uuid := auth.uid();
  v_test_user_id uuid;
  v_match_count integer;
  v_member_count integer;
  v_owned_waiting_room_id uuid;
begin
  if v_host_id is null then
    raise exception 'Authentication is required.';
  end if;

  if p_test_username is null
     or left(btrim(p_test_username), 5) <> 'test_' then
    raise exception 'Use a test profile username beginning with test_. ';
  end if;

  if not exists (
    select 1
    from public.group_rooms room
    join public.group_room_members host_member
      on host_member.room_id = room.id
     and host_member.user_id = v_host_id
     and host_member.role = 'host'
     and host_member.member_status <> 'left'
    where room.id = p_room_id
      and room.host_user_id = v_host_id
      and room.status = 'waiting'
      and room.journey_id is null
  ) then
    raise exception 'Only the active host can add a test account to a waiting room.';
  end if;

  select count(*)::integer
  into v_match_count
  from public.profiles profile
  where profile.username = btrim(p_test_username)
    and left(profile.username, 5) = 'test_';

  if v_match_count <> 1 then
    raise exception 'A unique test_ profile with that username was not found.';
  end if;

  select profile.id
  into v_test_user_id
  from public.profiles profile
  where profile.username = btrim(p_test_username)
    and left(profile.username, 5) = 'test_';

  if v_test_user_id = v_host_id then
    raise exception 'The host cannot be added as the test member.';
  end if;

  if exists (
    select 1
    from public.journey_participants participant
    where participant.user_id = v_test_user_id
      and participant.participant_status = 'active'
  ) then
    raise exception 'That test account already has an active journey.';
  end if;

  select owned_room.id
  into v_owned_waiting_room_id
  from public.group_rooms owned_room
  where owned_room.host_user_id = v_test_user_id
    and owned_room.status = 'waiting'
    and owned_room.journey_id is null
    and (
      select count(*)
      from public.group_room_members owned_member
      where owned_member.room_id = owned_room.id
        and owned_member.member_status <> 'left'
    ) = 1
  order by owned_room.created_at desc
  limit 1;

  if v_owned_waiting_room_id is not null then
    delete from public.group_rooms
    where id = v_owned_waiting_room_id
      and host_user_id = v_test_user_id
      and status = 'waiting'
      and journey_id is null;
  end if;

  if exists (
    select 1
    from public.group_room_members membership
    join public.group_rooms occupied_room
      on occupied_room.id = membership.room_id
     and occupied_room.status in ('waiting', 'active')
    where membership.user_id = v_test_user_id
      and membership.member_status <> 'left'
  ) then
    raise exception 'That test account already has an active room.';
  end if;

  select count(*)::integer
  into v_member_count
  from public.group_room_members membership
  where membership.room_id = p_room_id
    and membership.member_status <> 'left';

  if v_member_count >= 4 then
    raise exception 'This waiting room is already full.';
  end if;

  insert into public.group_room_members (
    room_id,
    user_id,
    role,
    member_status,
    left_at
  ) values (
    p_room_id,
    v_test_user_id,
    'member',
    'waiting',
    null
  )
  on conflict (room_id, user_id) do update
  set role = 'member',
      member_status = 'waiting',
      left_at = null;

  return v_test_user_id;
end;
$function$;

CREATE OR REPLACE FUNCTION public.add_owner_as_admin()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$ begin insert into plan_members(plan_id,user_id,role) values(new.id,new.owner_id,'admin') on conflict do nothing; return new; end $function$;

CREATE OR REPLACE FUNCTION public.cast_group_action_vote (
  p_journey_id uuid,
  p_vote_type  text,
  p_vote_round integer
)
  RETURNS jsonb
  LANGUAGE sql
  SECURITY DEFINER
  SET search_path TO 'public', 'pg_temp'
  AS $function$
  select public.cast_group_action_vote(
    p_journey_id, p_vote_type, p_vote_round, false
  );
$function$;

CREATE OR REPLACE FUNCTION public.cast_group_action_vote (
  p_journey_id             uuid,
  p_vote_type              text,
  p_vote_round             integer,
  p_simulate_test_explorer boolean
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public', 'pg_temp'
  AS $function$
declare
  v_actor_id uuid := auth.uid();
  v_voter_id uuid;
  v_room_id uuid;
  v_host_user_id uuid;
  v_clue_id uuid;
  v_unlocked_rounds integer;
  v_result jsonb;
  v_vote_id uuid;
  v_already_voted boolean;
begin
  if v_actor_id is null then
    raise exception 'Authentication is required.';
  end if;
  if p_vote_type not in ('hint', 'route') or p_vote_round < 1 then
    raise exception 'Invalid group vote.';
  end if;

  perform pg_advisory_xact_lock(
    hashtextextended(
      p_journey_id::text || ':' || p_vote_type || ':' || p_vote_round::text,
      0
    )
  );

  select room.id, room.host_user_id
    into v_room_id, v_host_user_id
  from public.group_rooms room
  join public.mystery_journeys journey on journey.id = room.journey_id
  where journey.id = p_journey_id
    and journey.mode = 'group'
    and journey.status = 'active'
    and room.status = 'active';

  if v_room_id is null then
    raise exception 'This Group Journey is no longer active.';
  end if;
  if not exists (
    select 1 from public.journey_participants participant
    where participant.journey_id = p_journey_id
      and participant.user_id = v_actor_id
      and participant.participant_status = 'active'
  ) then
    raise exception 'Only active journey participants can vote.';
  end if;

  if coalesce(p_simulate_test_explorer, false) then
    if v_host_user_id <> v_actor_id then
      raise exception 'Only the room host can simulate the test companion vote.';
    end if;
    select profile.id
      into v_voter_id
    from public.profiles profile
    join public.journey_participants participant
      on participant.user_id = profile.id
     and participant.journey_id = p_journey_id
     and participant.participant_status = 'active'
    where profile.username = 'test_explorer';
    if v_voter_id is null then
      raise exception 'Test Explorer is not an active participant.';
    end if;
  else
    v_voter_id := v_actor_id;
  end if;

  if p_vote_type = 'hint' then
    select count(distinct unlocked.clue_id)::integer
      into v_unlocked_rounds
    from public.participant_hint_unlocks unlocked
    join public.journey_participants participant
      on participant.id = unlocked.participant_id
    where participant.journey_id = p_journey_id;
    if p_vote_round <> v_unlocked_rounds + 1 then
      raise exception 'This hint vote round is no longer current.';
    end if;
  elsif p_vote_round <> 1 then
    raise exception 'Reveal route only supports vote round 1.';
  end if;

  insert into public.group_action_votes (
    journey_id, room_id, user_id, vote_type, vote_round, vote_yes
  ) values (
    p_journey_id, v_room_id, v_voter_id, p_vote_type, p_vote_round, true
  )
  on conflict (journey_id, vote_type, vote_round, user_id) do nothing
  returning id into v_vote_id;
  v_already_voted := v_vote_id is null;

  v_result := public.get_group_action_vote_status(
    p_journey_id, p_vote_type, p_vote_round
  );

  if (v_result ->> 'passed')::boolean and p_vote_type = 'route' then
    update public.mystery_journeys
       set exact_route_revealed = true
     where id = p_journey_id
       and status = 'active'
       and not exact_route_revealed;
  elsif (v_result ->> 'passed')::boolean and p_vote_type = 'hint' then
    select clue.id
      into v_clue_id
    from public.destination_clues clue
    join public.mystery_journeys journey
      on journey.destination_id = clue.destination_id
    where journey.id = p_journey_id
      and clue.clue_type = 'additional'
    order by clue.clue_order, clue.created_at, clue.id
    offset (p_vote_round - 1)
    limit 1;

    if v_clue_id is null then
      raise exception 'No more group hints are available.';
    end if;

    insert into public.participant_hint_unlocks (participant_id, clue_id)
    select participant.id, v_clue_id
    from public.journey_participants participant
    where participant.journey_id = p_journey_id
      and participant.participant_status = 'active'
      and not exists (
        select 1 from public.participant_hint_unlocks unlocked
        where unlocked.participant_id = participant.id
          and unlocked.clue_id = v_clue_id
      );
  end if;

  return v_result || jsonb_build_object('already_voted', v_already_voted);
end;
$function$;

CREATE OR REPLACE FUNCTION public.cleanup_group_journey_end_state()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public', 'pg_temp'
  AS $function$
declare
  v_now timestamptz := now();
begin
  if new.mode = 'group'
     and new.status in ('completed', 'cancelled')
     and new.status is distinct from old.status then
    update public.journey_participants
    set participant_status = 'cancelled',
        cancelled_at = coalesce(cancelled_at, v_now),
        updated_at = v_now
    where journey_id = new.id
      and participant_status = 'active';

    update public.group_rooms
    set status = case
          when new.status = 'completed' then 'closed'
          else 'cancelled'
        end,
        closed_at = coalesce(closed_at, v_now),
        updated_at = v_now
    where journey_id = new.id
      and status in ('waiting', 'active');
  end if;

  return new;
end;
$function$;

CREATE OR REPLACE FUNCTION public.cleanup_group_room_end_state()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public', 'pg_temp'
  AS $function$
declare
  v_now timestamptz := now();
begin
  if new.status in ('closed', 'cancelled', 'expired')
     and new.status is distinct from old.status then
    update public.group_room_members
    set member_status = 'left',
        left_at = coalesce(left_at, v_now)
    where room_id = new.id
      and member_status <> 'left';

    if new.journey_id is not null then
      update public.journey_participants
      set participant_status = 'cancelled',
          cancelled_at = coalesce(cancelled_at, v_now),
          updated_at = v_now
      where journey_id = new.journey_id
        and participant_status = 'active';

      update public.mystery_journeys
      set status = case
            when new.status = 'closed' then 'completed'
            else 'cancelled'
          end,
          completed_at = case
            when new.status = 'closed' then coalesce(completed_at, v_now)
            else completed_at
          end,
          cancelled_at = case
            when new.status in ('cancelled', 'expired') then coalesce(cancelled_at, v_now)
            else cancelled_at
          end,
          updated_at = v_now
      where id = new.journey_id
        and status = 'active';
    end if;
  end if;

  return new;
end;
$function$;

CREATE OR REPLACE FUNCTION public.complete_journey_participant (
  p_journey_id             uuid,
  p_latitude               double precision,
  p_longitude              double precision,
  p_distance_meters        double precision,
  p_simulate_test_explorer boolean          DEFAULT false
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public', 'pg_temp'
  AS $function$
declare
  v_actor uuid := auth.uid();
  v_target_user uuid;
  v_target_participant public.journey_participants%rowtype;
  v_journey public.mystery_journeys%rowtype;
  v_room public.group_rooms%rowtype;
  v_now timestamptz := now();
  v_rewarded boolean := false;
  v_journey_closed boolean := false;
begin
  if v_actor is null then
    raise exception 'Authentication is required' using errcode = '42501';
  end if;

  select *
    into v_journey
    from public.mystery_journeys
   where id = p_journey_id;

  if not found then
    raise exception 'Mystery Journey was not found' using errcode = 'P0002';
  end if;

  if p_simulate_test_explorer then
    if v_journey.mode <> 'group' then
      raise exception 'Test Explorer simulation requires a Group Journey'
        using errcode = '42501';
    end if;

    select *
      into v_room
      from public.group_rooms
     where journey_id = p_journey_id
       and host_user_id = v_actor
       and status = 'active';

    if not found then
      raise exception 'Only the active room host can simulate Test Explorer'
        using errcode = '42501';
    end if;

    if not exists (
      select 1
        from public.journey_participants actor_participant
       where actor_participant.journey_id = p_journey_id
         and actor_participant.user_id = v_actor
         and actor_participant.participant_status = 'active'
    ) then
      raise exception 'The host must be an active journey participant'
        using errcode = '42501';
    end if;

    select id
      into v_target_user
      from public.profiles
     where username = 'test_explorer';

    if v_target_user is null then
      raise exception 'Test Explorer profile was not found' using errcode = 'P0002';
    end if;
  else
    v_target_user := v_actor;
  end if;

  select *
    into v_target_participant
    from public.journey_participants
   where journey_id = p_journey_id
     and user_id = v_target_user
   for update;

  if not found then
    raise exception 'Journey participant was not found' using errcode = 'P0002';
  end if;

  if v_target_participant.participant_status <> 'active' then
    return jsonb_build_object(
      'completed', false,
      'already_completed', v_target_participant.participant_status = 'completed',
      'rewarded', false,
      'journey_closed', v_journey.status = 'completed',
      'target_user_id', v_target_user
    );
  end if;

  if v_journey.status <> 'active' then
    raise exception 'Mystery Journey is not active' using errcode = 'P0001';
  end if;

  insert into public.arrival_verifications (
    participant_id,
    latitude,
    longitude,
    distance_meters,
    verification_status,
    verified_at
  ) values (
    v_target_participant.id,
    p_latitude,
    p_longitude,
    p_distance_meters,
    'verified',
    v_now
  );

  update public.journey_participants
     set participant_status = 'completed',
         completed_at = v_now,
         updated_at = v_now
   where id = v_target_participant.id
     and participant_status = 'active';

  if not p_simulate_test_explorer then
    update public.profiles
       set xp = xp + 100,
           explorer_level = greatest(
             explorer_level,
             floor((xp + 100) / 500.0)::integer + 1
           ),
           streak_days = streak_days + 1,
           updated_at = v_now
     where id = v_actor;
    v_rewarded := found;
  end if;

  if v_journey.mode = 'solo' then
    update public.mystery_journeys
       set status = 'completed',
           completed_at = v_now,
           updated_at = v_now
     where id = p_journey_id
       and status = 'active';
    v_journey_closed := true;
  elsif not exists (
    select 1
      from public.journey_participants remaining
     where remaining.journey_id = p_journey_id
       and remaining.participant_status = 'active'
  ) then
    update public.mystery_journeys
       set status = 'completed',
           completed_at = v_now,
           updated_at = v_now
     where id = p_journey_id
       and status = 'active';

    update public.group_rooms
       set status = 'closed',
           closed_at = v_now,
           updated_at = v_now
     where journey_id = p_journey_id
       and status = 'active';
    v_journey_closed := true;
  end if;

  return jsonb_build_object(
    'completed', true,
    'already_completed', false,
    'rewarded', v_rewarded,
    'journey_closed', v_journey_closed,
    'target_user_id', v_target_user
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.expire_group_room (
  p_room_id uuid
)
  RETURNS boolean
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public', 'pg_temp'
  AS $function$
declare
  v_actor uuid := auth.uid();
  v_room public.group_rooms%rowtype;
begin
  if v_actor is null then
    raise exception 'Authentication is required' using errcode = '42501';
  end if;

  select * into v_room
  from public.group_rooms
  where id = p_room_id
  for update;

  if not found then
    return false;
  end if;

  if not exists (
    select 1
    from public.group_room_members member
    where member.room_id = p_room_id
      and member.user_id = v_actor
      and member.member_status <> 'left'
  ) then
    raise exception 'Only a current room member can expire this room'
      using errcode = '42501';
  end if;

  if v_room.status not in ('waiting', 'active')
     or v_room.expires_at > now() then
    return false;
  end if;

  update public.group_rooms
  set status = 'expired',
      closed_at = now(),
      updated_at = now()
  where id = p_room_id
    and status in ('waiting', 'active');

  return found;
end;
$function$;

CREATE OR REPLACE FUNCTION public.get_group_action_vote_status (
  p_journey_id uuid,
  p_vote_type  text,
  p_vote_round integer
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public', 'pg_temp'
  AS $function$
declare
  v_user_id uuid := auth.uid();
  v_room_id uuid;
  v_member_count integer;
  v_required_votes integer;
  v_yes_votes integer;
  v_current_user_voted boolean;
  v_test_explorer_voted boolean;
begin
  if v_user_id is null then
    raise exception 'Authentication is required.';
  end if;
  if p_vote_type not in ('hint', 'route') or p_vote_round < 1 then
    raise exception 'Invalid group vote.';
  end if;

  select room.id
    into v_room_id
  from public.group_rooms room
  join public.mystery_journeys journey on journey.id = room.journey_id
  where journey.id = p_journey_id
    and journey.mode = 'group'
    and journey.status = 'active'
    and room.status = 'active';

  if v_room_id is null then
    raise exception 'This Group Journey is no longer active.';
  end if;
  if not exists (
    select 1 from public.journey_participants participant
    where participant.journey_id = p_journey_id
      and participant.user_id = v_user_id
      and participant.participant_status = 'active'
  ) then
    raise exception 'Only active journey participants can view votes.';
  end if;

  select count(*)::integer
    into v_member_count
  from public.journey_participants participant
  where participant.journey_id = p_journey_id
    and participant.participant_status = 'active';

  v_required_votes := floor(v_member_count / 2.0)::integer + 1;

  select count(*) filter (where vote.vote_yes)::integer
    into v_yes_votes
  from public.group_action_votes vote
  where vote.journey_id = p_journey_id
    and vote.vote_type = p_vote_type
    and vote.vote_round = p_vote_round;

  select exists (
    select 1 from public.group_action_votes vote
    where vote.journey_id = p_journey_id
      and vote.vote_type = p_vote_type
      and vote.vote_round = p_vote_round
      and vote.user_id = v_user_id
      and vote.vote_yes
  ) into v_current_user_voted;

  select exists (
    select 1
    from public.group_action_votes vote
    join public.profiles profile on profile.id = vote.user_id
    where vote.journey_id = p_journey_id
      and vote.vote_type = p_vote_type
      and vote.vote_round = p_vote_round
      and vote.vote_yes
      and profile.username = 'test_explorer'
  ) into v_test_explorer_voted;

  return jsonb_build_object(
    'vote_round', p_vote_round,
    'yes_votes', v_yes_votes,
    'required_votes', v_required_votes,
    'member_count', v_member_count,
    'passed', v_yes_votes >= v_required_votes,
    'current_user_voted', v_current_user_voted,
    'test_explorer_voted', v_test_explorer_voted,
    'already_voted', false
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.handle_new_user()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO ''
  AS $function$
begin
  insert into public.profiles (
    id,
    username,
    full_name
  )
  values (
    new.id,
    new.raw_user_meta_data ->> 'username',
    new.raw_user_meta_data ->> 'full_name'
  );

  return new;
end;
$function$;

CREATE OR REPLACE FUNCTION public.is_plan_admin (
  target_plan uuid
)
  RETURNS boolean
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$ select exists(select 1 from travel_plans where id=target_plan and owner_id=auth.uid()) or exists(select 1 from plan_members where plan_id=target_plan and user_id=auth.uid() and role='admin') $function$;

CREATE OR REPLACE FUNCTION public.is_plan_member (
  target_plan uuid
)
  RETURNS boolean
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$ select exists(select 1 from plan_members where plan_id=target_plan and user_id=auth.uid()) or exists(select 1 from travel_plans where id=target_plan and owner_id=auth.uid()) $function$;

CREATE OR REPLACE FUNCTION public.join_travel_plan (
  invite_pin text
)
  RETURNS uuid
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$ declare target uuid; begin if auth.uid() is null then raise exception 'authentication required'; end if; select id into target from travel_plans where upper(invite_code)=upper(trim(invite_pin)); if target is null then raise exception 'invalid invite code'; end if; insert into plan_members(plan_id,user_id,role) values(target,auth.uid(),'member') on conflict do nothing; return target; end $function$;

CREATE OR REPLACE FUNCTION public.leave_group_room (
  p_room_id uuid
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public', 'pg_temp'
  AS $function$
declare
  v_actor uuid := auth.uid();
  v_room public.group_rooms%rowtype;
  v_member public.group_room_members%rowtype;
  v_now timestamptz := now();
  v_active_remaining integer := 0;
begin
  if v_actor is null then
    raise exception 'Authentication is required' using errcode = '42501';
  end if;

  select * into v_room
  from public.group_rooms
  where id = p_room_id
  for update;

  if not found then
    raise exception 'Group room was not found' using errcode = 'P0002';
  end if;

  select * into v_member
  from public.group_room_members
  where room_id = p_room_id
    and user_id = v_actor;

  if not found then
    raise exception 'You are not a member of this room' using errcode = '42501';
  end if;

  if v_member.member_status = 'left' then
    return jsonb_build_object(
      'left', false,
      'already_left', true,
      'room_status', v_room.status
    );
  end if;

  if v_room.status = 'waiting' then
    if v_room.host_user_id = v_actor then
      update public.group_rooms
      set status = 'cancelled',
          closed_at = v_now,
          updated_at = v_now
      where id = p_room_id
        and status = 'waiting';

      return jsonb_build_object(
        'left', true,
        'room_status', 'cancelled',
        'journey_status', null
      );
    end if;

    update public.group_room_members
    set member_status = 'left',
        left_at = v_now
    where id = v_member.id
      and member_status <> 'left';

    return jsonb_build_object(
      'left', true,
      'room_status', 'waiting',
      'journey_status', null
    );
  end if;

  if v_room.status = 'active' and v_room.journey_id is not null then
    update public.journey_participants
    set participant_status = 'cancelled',
        cancelled_at = v_now,
        updated_at = v_now
    where journey_id = v_room.journey_id
      and user_id = v_actor
      and participant_status = 'active';

    update public.group_room_members
    set member_status = 'left',
        left_at = v_now
    where id = v_member.id
      and member_status <> 'left';

    select count(*)::integer into v_active_remaining
    from public.journey_participants
    where journey_id = v_room.journey_id
      and participant_status = 'active';

    if v_active_remaining = 0 then
      update public.mystery_journeys
      set status = 'completed',
          completed_at = coalesce(completed_at, v_now),
          updated_at = v_now
      where id = v_room.journey_id
        and status = 'active';
    end if;

    return jsonb_build_object(
      'left', true,
      'room_status', case when v_active_remaining = 0 then 'closed' else 'active' end,
      'journey_status', case when v_active_remaining = 0 then 'completed' else 'active' end,
      'active_participants', v_active_remaining
    );
  end if;

  update public.group_room_members
  set member_status = 'left',
      left_at = coalesce(left_at, v_now)
  where id = v_member.id
    and member_status <> 'left';

  return jsonb_build_object(
    'left', true,
    'room_status', v_room.status,
    'journey_status', null
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.set_group_room_ready (
  p_room_id  uuid,
  p_is_ready boolean
)
  RETURNS void
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public', 'pg_temp'
  AS $function$
declare
  v_user_id uuid := auth.uid();
  v_updated integer;
begin
  if v_user_id is null then
    raise exception 'Authentication is required.';
  end if;

  if not exists (
    select 1
    from public.group_rooms room
    where room.id = p_room_id
      and room.status = 'waiting'
      and room.journey_id is null
      and room.expires_at > now()
  ) then
    raise exception 'Ready status is only available in an active waiting room.';
  end if;

  update public.group_room_members
  set is_ready = p_is_ready
  where room_id = p_room_id
    and user_id = v_user_id
    and member_status = 'waiting';

  get diagnostics v_updated = row_count;
  if v_updated <> 1 then
    raise exception 'You are not an active member of this waiting room.';
  end if;
end;
$function$;

CREATE OR REPLACE FUNCTION public.set_updated_at()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  AS $function$
begin
  new.updated_at = now();
  return new;
end;
$function$;

CREATE OR REPLACE FUNCTION public.validate_group_room_host()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  AS $function$
BEGIN
  IF NEW.status = 'waiting' THEN
    IF NOT EXISTS (
      SELECT 1
      FROM public.group_room_members m
      WHERE m.room_id = NEW.id
        AND m.user_id = NEW.host_user_id
        AND m.role = 'host'
        AND m.member_status <> 'left'
    ) THEN
      RAISE EXCEPTION
        'Waiting group room host must exist as an active host member';
    END IF;
  END IF;

  RETURN NEW;
END;
$function$;

ALTER TABLE "public"."destination_clues"
  ADD CONSTRAINT "destination_clues_destination_id_fkey" FOREIGN KEY (destination_id) REFERENCES public.destinations(id) ON DELETE CASCADE;

ALTER TABLE "public"."group_action_votes"
  ADD CONSTRAINT "group_action_votes_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;

ALTER TABLE "public"."group_chat_messages"
  ADD CONSTRAINT "group_chat_messages_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;

ALTER TABLE "public"."group_action_votes"
  ADD CONSTRAINT "group_action_votes_room_id_fkey" FOREIGN KEY (room_id) REFERENCES public.group_rooms(id) ON DELETE CASCADE;

ALTER TABLE "public"."group_chat_messages"
  ADD CONSTRAINT "group_chat_messages_room_id_fkey" FOREIGN KEY (room_id) REFERENCES public.group_rooms(id) ON DELETE CASCADE;

ALTER TABLE "public"."group_room_members"
  ADD CONSTRAINT "group_room_members_room_id_fkey" FOREIGN KEY (room_id) REFERENCES public.group_rooms(id) ON DELETE CASCADE;

ALTER TABLE "public"."arrival_verifications"
  ADD CONSTRAINT "arrival_verifications_participant_id_fkey" FOREIGN KEY (participant_id) REFERENCES public.journey_participants(id) ON DELETE CASCADE;

ALTER TABLE "public"."mystery_journeys"
  ADD CONSTRAINT "mystery_journeys_destination_id_fkey" FOREIGN KEY (destination_id) REFERENCES public.destinations(id);

ALTER TABLE "public"."mystery_journeys"
  ADD CONSTRAINT "mystery_journeys_initial_clue_id_fkey" FOREIGN KEY (initial_clue_id) REFERENCES public.destination_clues(id);

ALTER TABLE "public"."group_action_votes"
  ADD CONSTRAINT "group_action_votes_journey_id_fkey" FOREIGN KEY (journey_id) REFERENCES public.mystery_journeys(id) ON DELETE CASCADE;

ALTER TABLE "public"."group_rooms"
  ADD CONSTRAINT "group_rooms_journey_id_fkey" FOREIGN KEY (journey_id) REFERENCES public.mystery_journeys(id) ON DELETE SET NULL;

ALTER TABLE "public"."journey_participants"
  ADD CONSTRAINT "journey_participants_journey_id_fkey" FOREIGN KEY (journey_id) REFERENCES public.mystery_journeys(id) ON DELETE CASCADE;

ALTER TABLE "public"."journey_preference_categories"
  ADD CONSTRAINT "journey_preference_categories_journey_id_fkey" FOREIGN KEY (journey_id) REFERENCES public.mystery_journeys(id) ON DELETE CASCADE;

ALTER TABLE "public"."participant_hint_unlocks"
  ADD CONSTRAINT "participant_hint_unlocks_clue_id_fkey" FOREIGN KEY (clue_id) REFERENCES public.destination_clues(id) ON DELETE CASCADE;

ALTER TABLE "public"."participant_hint_unlocks"
  ADD CONSTRAINT "participant_hint_unlocks_participant_id_fkey" FOREIGN KEY (participant_id) REFERENCES public.journey_participants(id) ON DELETE CASCADE;

ALTER TABLE "public"."itinerary_cards"
  ADD CONSTRAINT "itinerary_cards_day_id_fkey" FOREIGN KEY (day_id) REFERENCES public.plan_days(id) ON DELETE CASCADE;

ALTER TABLE "public"."plan_members"
  ADD CONSTRAINT "plan_members_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;

ALTER TABLE "public"."profiles"
  ADD CONSTRAINT "profiles_id_fkey" FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE;

ALTER TABLE "public"."group_room_members"
  ADD CONSTRAINT "group_room_members_user_id_fkey" FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE;

ALTER TABLE "public"."group_rooms"
  ADD CONSTRAINT "group_rooms_host_user_id_fkey" FOREIGN KEY (host_user_id) REFERENCES public.profiles(id) ON DELETE CASCADE;

ALTER TABLE "public"."journey_participants"
  ADD CONSTRAINT "journey_participants_user_id_fkey" FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE;

ALTER TABLE "public"."travel_plans"
  ADD CONSTRAINT "travel_plans_owner_id_fkey" FOREIGN KEY (owner_id) REFERENCES auth.users(id) ON DELETE CASCADE;

ALTER TABLE "public"."plan_days"
  ADD CONSTRAINT "plan_days_plan_id_fkey" FOREIGN KEY (plan_id) REFERENCES public.travel_plans(id) ON DELETE CASCADE;

ALTER TABLE "public"."plan_members"
  ADD CONSTRAINT "plan_members_plan_id_fkey" FOREIGN KEY (plan_id) REFERENCES public.travel_plans(id) ON DELETE CASCADE;

ALTER TABLE "public"."user_preference_categories"
  ADD CONSTRAINT "user_preference_categories_preference_id_fkey" FOREIGN KEY (preference_id) REFERENCES public.user_preferences(id) ON DELETE CASCADE;

ALTER TABLE "public"."user_preferences"
  ADD CONSTRAINT "user_preferences_user_id_fkey" FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE;

CREATE INDEX group_action_votes_journey_round_idx ON public.group_action_votes USING btree (journey_id, vote_type, vote_round);

CREATE INDEX group_chat_messages_room_created_idx ON public.group_chat_messages USING btree (room_id, created_at);

CREATE INDEX itinerary_cards_day_idx ON public.itinerary_cards USING btree (day_id, "position");

CREATE UNIQUE INDEX one_host_per_room ON public.group_room_members USING btree (room_id)
  WHERE (ROLE = 'host'::text);

CREATE INDEX plan_days_plan_idx ON public.plan_days USING btree (plan_id, date);

CREATE INDEX plan_members_user_idx ON public.plan_members USING btree (user_id);

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_user();

CREATE TRIGGER set_destinations_updated_at
  BEFORE UPDATE ON public.destinations
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER cleanup_group_room_end_state_on_update
  AFTER UPDATE OF status ON public.group_rooms
  FOR EACH ROW
  EXECUTE FUNCTION public.cleanup_group_room_end_state();

CREATE TRIGGER set_group_rooms_updated_at
  BEFORE UPDATE ON public.group_rooms
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER validate_group_room_host_on_update
  BEFORE UPDATE ON public.group_rooms
  FOR EACH ROW
  EXECUTE FUNCTION public.validate_group_room_host();

CREATE TRIGGER set_journey_participants_updated_at
  BEFORE UPDATE ON public.journey_participants
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER cleanup_group_journey_end_state_on_update
  AFTER UPDATE OF status ON public.mystery_journeys
  FOR EACH ROW
  EXECUTE FUNCTION public.cleanup_group_journey_end_state();

CREATE TRIGGER set_mystery_journeys_updated_at
  BEFORE UPDATE ON public.mystery_journeys
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER set_profiles_updated_at
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER travel_plan_owner_membership
  AFTER INSERT ON public.travel_plans
  FOR EACH ROW
  EXECUTE FUNCTION public.add_owner_as_admin();

CREATE TRIGGER set_user_preferences_updated_at
  BEFORE UPDATE ON public.user_preferences
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

CREATE POLICY "Users can view own arrival verifications" ON "public"."arrival_verifications"
  FOR SELECT
  TO "authenticated"
  USING ((EXISTS ( SELECT 1
   FROM public.journey_participants jp
  WHERE ((jp.id = arrival_verifications.participant_id) AND (jp.user_id = auth.uid())))));

CREATE POLICY "app_arrival_insert_own" ON "public"."arrival_verifications"
  FOR INSERT
  TO "authenticated"
  WITH CHECK ((EXISTS ( SELECT 1
   FROM public.journey_participants jp
  WHERE ((jp.id = arrival_verifications.participant_id) AND (jp.user_id = auth.uid())))));

CREATE POLICY "app_arrival_select_own" ON "public"."arrival_verifications"
  FOR SELECT
  TO "authenticated"
  USING ((EXISTS ( SELECT 1
   FROM public.journey_participants jp
  WHERE ((jp.id = arrival_verifications.participant_id) AND (jp.user_id = auth.uid())))));

CREATE POLICY "Authenticated users can read destination clues" ON "public"."destination_clues"
  FOR SELECT
  TO "authenticated"
  USING ((EXISTS ( SELECT 1
   FROM public.destinations d
  WHERE ((d.id = destination_clues.destination_id) AND (d.is_active = true)))));

CREATE POLICY "Authenticated users can read active destinations" ON "public"."destinations"
  FOR SELECT
  TO "authenticated"
  USING ((is_active = true));

CREATE POLICY "group_action_votes_select_participant" ON "public"."group_action_votes"
  FOR SELECT
  TO "authenticated"
  USING ((EXISTS ( SELECT 1
   FROM public.journey_participants participant
  WHERE ((participant.journey_id = group_action_votes.journey_id) AND (participant.user_id = auth.uid()) AND (participant.participant_status = 'active'::text)))));

CREATE POLICY "group_chat_messages_insert_member" ON "public"."group_chat_messages"
  FOR INSERT
  TO "authenticated"
  WITH CHECK (((user_id = auth.uid()) AND (EXISTS ( SELECT 1
   FROM public.group_room_members member
  WHERE ((member.room_id = group_chat_messages.room_id) AND (member.user_id = auth.uid()) AND (member.member_status <> 'left'::text)))) AND (( SELECT count(*) AS count
   FROM public.group_room_members active_member
  WHERE ((active_member.room_id = group_chat_messages.room_id) AND (active_member.member_status <> 'left'::text))) >= 2)));

CREATE POLICY "group_chat_messages_select_member" ON "public"."group_chat_messages"
  FOR SELECT
  TO "authenticated"
  USING (((EXISTS ( SELECT 1
   FROM public.group_room_members member
  WHERE ((member.room_id = group_chat_messages.room_id) AND (member.user_id = auth.uid()) AND (member.member_status <> 'left'::text)))) AND (( SELECT count(*) AS count
   FROM public.group_room_members active_member
  WHERE ((active_member.room_id = group_chat_messages.room_id) AND (active_member.member_status <> 'left'::text))) >= 2)));

CREATE POLICY "group_room_members_insert_self" ON "public"."group_room_members"
  FOR INSERT
  TO "authenticated"
  WITH CHECK (((user_id = ( SELECT auth.uid() AS uid)) AND (EXISTS ( SELECT 1
   FROM public.group_rooms room
  WHERE
    ((room.id = group_room_members.room_id) AND (room.status = 'waiting'::text) AND ((group_room_members.role = 'member'::text) OR ((group_room_members.role = 'host'::text) AND
    (room.host_user_id = ( SELECT auth.uid() AS uid)))))))));

CREATE POLICY "group_room_members_select_authenticated" ON "public"."group_room_members"
  FOR SELECT
  TO "authenticated"
  USING (true);

CREATE POLICY "group_room_members_update_by_host" ON "public"."group_room_members"
  FOR UPDATE
  TO "authenticated"
  USING ((EXISTS ( SELECT 1
   FROM public.group_rooms room
  WHERE ((room.id = group_room_members.room_id) AND (room.host_user_id = ( SELECT auth.uid() AS uid))))))
  WITH CHECK ((EXISTS ( SELECT 1
   FROM public.group_rooms room
  WHERE ((room.id = group_room_members.room_id) AND (room.host_user_id = ( SELECT auth.uid() AS uid))))));

CREATE POLICY "group_room_members_update_self" ON "public"."group_room_members"
  FOR UPDATE
  TO "authenticated"
  USING ((user_id = ( SELECT auth.uid() AS uid)))
  WITH CHECK (((user_id = ( SELECT auth.uid() AS uid)) AND (role = 'member'::text)));

CREATE POLICY "group_rooms_delete_own_host" ON "public"."group_rooms"
  FOR DELETE
  TO "authenticated"
  USING ((host_user_id = ( SELECT auth.uid() AS uid)));

CREATE POLICY "group_rooms_insert_own_host" ON "public"."group_rooms"
  FOR INSERT
  TO "authenticated"
  WITH CHECK ((host_user_id = ( SELECT auth.uid() AS uid)));

CREATE POLICY "group_rooms_select_authenticated" ON "public"."group_rooms"
  FOR SELECT
  TO "authenticated"
  USING (true);

CREATE POLICY "group_rooms_update_own_host" ON "public"."group_rooms"
  FOR UPDATE
  TO "authenticated"
  USING ((host_user_id = ( SELECT auth.uid() AS uid)))
  WITH CHECK (true);

CREATE POLICY "members manage cards" ON "public"."itinerary_cards"
  FOR ALL
  TO PUBLIC
  USING ((EXISTS ( SELECT 1
   FROM public.plan_days d
  WHERE ((d.id = itinerary_cards.day_id) AND public.is_plan_member(d.plan_id)))))
  WITH CHECK ((EXISTS ( SELECT 1
   FROM public.plan_days d
  WHERE ((d.id = itinerary_cards.day_id) AND public.is_plan_member(d.plan_id)))));

CREATE POLICY "app_participant_insert_group_host" ON "public"."journey_participants"
  FOR INSERT
  TO "authenticated"
  WITH CHECK ((EXISTS ( SELECT 1
   FROM (public.group_rooms room
     JOIN public.group_room_members member ON (((member.room_id = room.id) AND (member.user_id = journey_participants.user_id))))
  WHERE ((room.host_user_id = auth.uid()) AND (room.journey_id = journey_participants.journey_id) AND (room.status = 'active'::text) AND (member.member_status <> 'left'::text)))));

CREATE POLICY "app_participant_select_group_members" ON "public"."journey_participants"
  FOR SELECT
  TO "authenticated"
  USING ((EXISTS ( SELECT 1
   FROM (public.group_rooms room
     JOIN public.group_room_members member ON ((member.room_id = room.id)))
  WHERE
    ((room.journey_id = journey_participants.journey_id) AND (member.user_id = auth.uid()) AND (((room.status = 'active'::text) AND (member.member_status <> 'left'::text)) OR
    (room.status = 'closed'::text))))));

CREATE POLICY "app_participant_select_self" ON "public"."journey_participants"
  FOR SELECT
  TO "authenticated"
  USING ((user_id = auth.uid()));

CREATE POLICY "app_participant_update_self" ON "public"."journey_participants"
  FOR UPDATE
  TO "authenticated"
  USING ((user_id = auth.uid()))
  WITH CHECK ((user_id = auth.uid()));

CREATE POLICY "app_mystery_select_group_members" ON "public"."mystery_journeys"
  FOR SELECT
  TO "authenticated"
  USING ((EXISTS ( SELECT 1
   FROM (public.group_rooms room
     JOIN public.group_room_members member ON ((member.room_id = room.id)))
  WHERE
    ((room.journey_id = mystery_journeys.id) AND (member.user_id = auth.uid()) AND (((room.status = 'active'::text) AND (member.member_status <> 'left'::text)) OR (room.status =
    'closed'::text))))));

CREATE POLICY "Users can view own unlocked hints" ON "public"."participant_hint_unlocks"
  FOR SELECT
  TO "authenticated"
  USING ((EXISTS ( SELECT 1
   FROM public.journey_participants jp
  WHERE ((jp.id = participant_hint_unlocks.participant_id) AND (jp.user_id = auth.uid())))));

CREATE POLICY "app_hint_unlock_insert_own" ON "public"."participant_hint_unlocks"
  FOR INSERT
  TO "authenticated"
  WITH CHECK ((EXISTS ( SELECT 1
   FROM public.journey_participants jp
  WHERE ((jp.id = participant_hint_unlocks.participant_id) AND (jp.user_id = auth.uid())))));

CREATE POLICY "app_hint_unlock_select_own" ON "public"."participant_hint_unlocks"
  FOR SELECT
  TO "authenticated"
  USING ((EXISTS ( SELECT 1
   FROM public.journey_participants jp
  WHERE ((jp.id = participant_hint_unlocks.participant_id) AND (jp.user_id = auth.uid())))));

CREATE POLICY "members manage days" ON "public"."plan_days"
  FOR ALL
  TO PUBLIC
  USING (public.is_plan_member(plan_id))
  WITH CHECK (public.is_plan_member(plan_id));

CREATE POLICY "admins manage membership" ON "public"."plan_members"
  FOR ALL
  TO PUBLIC
  USING (public.is_plan_admin(plan_id))
  WITH CHECK (public.is_plan_admin(plan_id));

CREATE POLICY "members read membership" ON "public"."plan_members"
  FOR SELECT
  TO PUBLIC
  USING (public.is_plan_member(plan_id));

CREATE POLICY "Users can update own profile" ON "public"."profiles"
  FOR UPDATE
  TO "authenticated"
  USING ((auth.uid() = id))
  WITH CHECK ((auth.uid() = id));

CREATE POLICY "Users can view own profile" ON "public"."profiles"
  FOR SELECT
  TO "authenticated"
  USING ((auth.uid() = id));

CREATE POLICY "app_profiles_select_shared_group_room" ON "public"."profiles"
  FOR SELECT
  TO "authenticated"
  USING ((EXISTS ( SELECT 1
   FROM ((public.group_room_members target_member
     JOIN public.group_rooms room ON ((room.id = target_member.room_id)))
     JOIN public.group_room_members viewer ON ((viewer.room_id = room.id)))
  WHERE
    ((target_member.user_id = profiles.id) AND (viewer.user_id = auth.uid()) AND (((room.status = ANY (ARRAY['waiting'::text, 'active'::text])) AND (target_member.member_status <>
    'left'::text) AND (viewer.member_status <> 'left'::text)) OR (room.status = 'closed'::text))))));

CREATE POLICY "admins delete plans" ON "public"."travel_plans"
  FOR DELETE
  TO PUBLIC
  USING (public.is_plan_admin(id));

CREATE POLICY "admins update plans" ON "public"."travel_plans"
  FOR UPDATE
  TO PUBLIC
  USING (public.is_plan_admin(id))
  WITH CHECK (public.is_plan_admin(id));

CREATE POLICY "members read plans" ON "public"."travel_plans"
  FOR SELECT
  TO PUBLIC
  USING (public.is_plan_member(id));

CREATE POLICY "owners create plans" ON "public"."travel_plans"
  FOR INSERT
  TO PUBLIC
  WITH CHECK ((owner_id = auth.uid()));

CREATE POLICY "Users can delete own preference categories" ON "public"."user_preference_categories"
  FOR DELETE
  TO "authenticated"
  USING ((EXISTS ( SELECT 1
   FROM public.user_preferences p
  WHERE ((p.id = user_preference_categories.preference_id) AND (p.user_id = auth.uid())))));

CREATE POLICY "Users can insert own preference categories" ON "public"."user_preference_categories"
  FOR INSERT
  TO "authenticated"
  WITH CHECK ((EXISTS ( SELECT 1
   FROM public.user_preferences p
  WHERE ((p.id = user_preference_categories.preference_id) AND (p.user_id = auth.uid())))));

CREATE POLICY "Users can view own preference categories" ON "public"."user_preference_categories"
  FOR SELECT
  TO "authenticated"
  USING ((EXISTS ( SELECT 1
   FROM public.user_preferences p
  WHERE ((p.id = user_preference_categories.preference_id) AND (p.user_id = auth.uid())))));

CREATE POLICY "Users can delete own preferences" ON "public"."user_preferences"
  FOR DELETE
  TO "authenticated"
  USING ((auth.uid() = user_id));

CREATE POLICY "Users can insert own preferences" ON "public"."user_preferences"
  FOR INSERT
  TO "authenticated"
  WITH CHECK ((auth.uid() = user_id));

CREATE POLICY "Users can update own preferences" ON "public"."user_preferences"
  FOR UPDATE
  TO "authenticated"
  USING ((auth.uid() = user_id))
  WITH CHECK ((auth.uid() = user_id));

CREATE POLICY "Users can view own preferences" ON "public"."user_preferences"
  FOR SELECT
  TO "authenticated"
  USING ((auth.uid() = user_id));

REVOKE ALL ON FUNCTION "public"."activate_group_room"(uuid, uuid, timestamp WITH time zone, timestamp WITH time zone) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION "public"."activate_group_room"(uuid, uuid, timestamp WITH time zone, timestamp WITH time zone) TO "authenticated", "postgres", "service_role";

REVOKE ALL ON FUNCTION "public"."add_group_test_member"(uuid, text) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION "public"."add_group_test_member"(uuid, text) TO "authenticated", "postgres", "service_role";

REVOKE ALL ON FUNCTION "public"."add_owner_as_admin"() FROM PUBLIC;

GRANT EXECUTE ON FUNCTION "public"."add_owner_as_admin"() TO "authenticated", "postgres", "service_role";

REVOKE ALL ON FUNCTION "public"."cast_group_action_vote"(uuid, text, integer) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION "public"."cast_group_action_vote"(uuid, text, integer) TO "authenticated", "postgres", "service_role";

REVOKE ALL ON FUNCTION "public"."cast_group_action_vote"(uuid, text, integer, boolean) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION "public"."cast_group_action_vote"(uuid, text, integer, boolean) TO "authenticated", "postgres", "service_role";

REVOKE ALL ON FUNCTION "public"."cleanup_group_journey_end_state"() FROM PUBLIC;

GRANT EXECUTE ON FUNCTION "public"."cleanup_group_journey_end_state"() TO "postgres", "service_role";

REVOKE ALL ON FUNCTION "public"."cleanup_group_room_end_state"() FROM PUBLIC;

GRANT EXECUTE ON FUNCTION "public"."cleanup_group_room_end_state"() TO "postgres", "service_role";

REVOKE ALL ON FUNCTION "public"."complete_journey_participant"(uuid, double precision, double precision, double precision, boolean) FROM PUBLIC;

GRANT EXECUTE
  ON FUNCTION "public"."complete_journey_participant"(uuid, double precision, double precision, double precision, boolean)
  TO "authenticated", "postgres", "service_role";

REVOKE ALL ON FUNCTION "public"."expire_group_room"(uuid) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION "public"."expire_group_room"(uuid) TO "authenticated", "postgres", "service_role";

REVOKE ALL ON FUNCTION "public"."get_group_action_vote_status"(uuid, text, integer) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION "public"."get_group_action_vote_status"(uuid, text, integer) TO "authenticated", "postgres", "service_role";

GRANT EXECUTE ON FUNCTION "public"."handle_new_user"() TO PUBLIC, "anon", "authenticated", "postgres", "service_role";

REVOKE ALL ON FUNCTION "public"."is_plan_admin"(uuid) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION "public"."is_plan_admin"(uuid) TO "authenticated", "postgres", "service_role";

REVOKE ALL ON FUNCTION "public"."is_plan_member"(uuid) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION "public"."is_plan_member"(uuid) TO "authenticated", "postgres", "service_role";

REVOKE ALL ON FUNCTION "public"."join_travel_plan"(text) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION "public"."join_travel_plan"(text) TO "authenticated", "postgres", "service_role";

REVOKE ALL ON FUNCTION "public"."leave_group_room"(uuid) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION "public"."leave_group_room"(uuid) TO "authenticated", "postgres", "service_role";

REVOKE ALL ON FUNCTION "public"."set_group_room_ready"(uuid, boolean) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION "public"."set_group_room_ready"(uuid, boolean) TO "authenticated", "postgres", "service_role";

GRANT EXECUTE ON FUNCTION "public"."set_updated_at"() TO PUBLIC, "anon", "authenticated", "postgres", "service_role";

GRANT EXECUTE ON FUNCTION "public"."validate_group_room_host"() TO PUBLIC, "anon", "authenticated", "postgres", "service_role";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."arrival_verifications" TO "anon", "authenticated", "postgres", "service_role";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."destination_clues" TO "anon", "authenticated", "postgres", "service_role";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."destinations" TO "anon", "authenticated", "postgres", "service_role";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."group_action_votes" TO "anon", "authenticated", "postgres", "service_role";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."group_chat_messages" TO "anon", "authenticated", "postgres", "service_role";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."group_room_members" TO "anon", "authenticated", "postgres", "service_role";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."group_rooms" TO "anon", "authenticated", "postgres", "service_role";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."itinerary_cards" TO "anon", "authenticated", "postgres", "service_role";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."journey_participants" TO "anon", "authenticated", "postgres", "service_role";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE
  ON TABLE "public"."journey_preference_categories"
  TO "anon", "authenticated", "postgres", "service_role";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."mystery_journeys" TO "anon", "authenticated", "postgres", "service_role";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."participant_hint_unlocks" TO "anon", "authenticated", "postgres", "service_role";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."plan_days" TO "anon", "authenticated", "postgres", "service_role";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."plan_members" TO "anon", "authenticated", "postgres", "service_role";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."profiles" TO "anon", "authenticated", "postgres", "service_role";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."travel_plans" TO "anon", "authenticated", "postgres", "service_role";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."user_preference_categories" TO "anon", "authenticated", "postgres", "service_role";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."user_preferences" TO "anon", "authenticated", "postgres", "service_role";

ALTER TABLE "public"."mystery_journeys"
  ADD CONSTRAINT "mystery_journeys_created_by_user_id_fkey" FOREIGN KEY (created_by_user_id) REFERENCES auth.users(id) ON DELETE CASCADE;

CREATE POLICY "app_participant_insert_self" ON "public"."journey_participants"
  FOR INSERT
  TO "authenticated"
  WITH CHECK (((user_id = auth.uid()) AND (EXISTS ( SELECT 1
   FROM public.mystery_journeys j
  WHERE ((j.id = journey_participants.journey_id) AND (j.created_by_user_id = auth.uid()))))));

CREATE POLICY "app_journey_categories_insert_own" ON "public"."journey_preference_categories"
  FOR INSERT
  TO "authenticated"
  WITH CHECK ((EXISTS ( SELECT 1
   FROM public.mystery_journeys j
  WHERE ((j.id = journey_preference_categories.journey_id) AND (j.created_by_user_id = auth.uid())))));

CREATE POLICY "app_journey_categories_select_own" ON "public"."journey_preference_categories"
  FOR SELECT
  TO "authenticated"
  USING ((EXISTS ( SELECT 1
   FROM public.mystery_journeys j
  WHERE ((j.id = journey_preference_categories.journey_id) AND (j.created_by_user_id = auth.uid())))));

CREATE POLICY "app_mystery_delete_own" ON "public"."mystery_journeys"
  FOR DELETE
  TO "authenticated"
  USING ((created_by_user_id = auth.uid()));

CREATE POLICY "app_mystery_insert_own" ON "public"."mystery_journeys"
  FOR INSERT
  TO "authenticated"
  WITH CHECK ((created_by_user_id = auth.uid()));

CREATE POLICY "app_mystery_select_own" ON "public"."mystery_journeys"
  FOR SELECT
  TO "authenticated"
  USING ((created_by_user_id = auth.uid()));

CREATE POLICY "app_mystery_update_own" ON "public"."mystery_journeys"
  FOR UPDATE
  TO "authenticated"
  USING ((created_by_user_id = auth.uid()))
  WITH CHECK ((created_by_user_id = auth.uid()));

