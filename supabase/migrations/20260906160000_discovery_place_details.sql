-- Cached Google Places details for the Discovery catalogue only.
-- The legacy opening_hours column is retained for existing OSM data.
alter table public.heritage_locations
  add column formatted_address text,
  add column opening_hours_weekday_text jsonb,
  add column opening_hours_periods jsonb,
  add column opening_hours_updated_at timestamptz,
  add column google_maps_uri text;
comment on column public.heritage_locations.formatted_address is
  'Google Places formatted address for an accepted Discovery POI match.';
comment on column public.heritage_locations.opening_hours_weekday_text is
  'Google Places regularOpeningHours.weekdayDescriptions cache.';
comment on column public.heritage_locations.opening_hours_periods is
  'Cached regular/current Google Places opening periods and current weekday descriptions.';
comment on column public.heritage_locations.opening_hours_updated_at is
  'Timestamp of the most recent Google Place Details refresh, including responses without hours.';
comment on column public.heritage_locations.google_maps_uri is
  'Google Maps place URI returned by Google Place Details.';
-- RLS, grants, existing rows and all Mystery Journey tables are unchanged.;
