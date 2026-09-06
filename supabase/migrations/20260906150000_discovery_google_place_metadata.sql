-- Discovery-only Google POI identity plus reusable image attribution metadata.
-- Google place IDs are stable/cacheable identifiers. Google photo resource
-- names are intentionally not persisted; demo photo URLs carry refresh_after.
alter table public.heritage_locations
  add column google_place_id text,
  add column google_place_name text,
  add column google_match_status text
    check (google_match_status in ('exact', 'high_confidence'));
create index heritage_locations_google_place_idx
  on public.heritage_locations (google_place_id)
  where google_place_id is not null;
alter table public.destination_images
  add column license_name text,
  add column license_url text,
  add column source_page_url text,
  add column refresh_after timestamptz;
comment on column public.heritage_locations.google_place_id is
  'Stable Google Places ID used only to validate the matching Discovery POI.';
comment on column public.destination_images.refresh_after is
  'Non-null only for short-lived demo image URLs that must be refreshed.';
create or replace view public.destination_image_covers
with (security_invoker = true)
as
select distinct on (destination_id)
  id,
  destination_id,
  image_url,
  source,
  source_image_id,
  photographer_name,
  photographer_url,
  is_cover,
  display_order,
  match_status,
  license_name,
  license_url,
  source_page_url,
  refresh_after
from public.destination_images
order by destination_id, is_cover desc, display_order asc, id asc;
