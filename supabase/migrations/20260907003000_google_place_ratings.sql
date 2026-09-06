-- Cache Google Places ratings for catalogue cards. App-authored reviews remain
-- in destination_reviews and are deliberately kept as a separate data source.
alter table public.heritage_locations
  add column if not exists google_rating double precision,
  add column if not exists google_user_rating_count integer,
  add column if not exists google_rating_updated_at timestamptz;

alter table public.heritage_locations
  drop constraint if exists heritage_locations_google_rating_check;
alter table public.heritage_locations
  add constraint heritage_locations_google_rating_check
  check (google_rating is null or google_rating between 1 and 5);

alter table public.heritage_locations
  drop constraint if exists heritage_locations_google_rating_count_check;
alter table public.heritage_locations
  add constraint heritage_locations_google_rating_count_check
  check (google_user_rating_count is null or google_user_rating_count >= 0);

comment on column public.heritage_locations.google_rating is
  'Google Places aggregate rating cached by the catalogue enrichment job.';
comment on column public.heritage_locations.google_user_rating_count is
  'Google Places userRatingCount cached alongside google_rating.';
