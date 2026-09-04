alter table public.journey_participants
  add column if not exists shaken_at timestamp with time zone;

comment on column public.journey_participants.shaken_at is
  'Timestamp when this participant completed the post-start group shake interaction.';
