-- Rebuild the view so the newly added Google rating cache columns are exposed.
drop view if exists public.displayable_heritage_locations;

create view public.displayable_heritage_locations
with (security_invoker = true)
as
select
  location.*,
  cover.image_url as cover_image_url,
  cover.source as cover_image_source,
  cover.refresh_after as cover_image_refresh_after
from public.heritage_locations as location
join public.destination_image_covers as cover
  on cover.destination_id = location.osm_id
where location.is_active
  and location.is_verified
  and nullif(btrim(location.google_place_id), '') is not null
  and nullif(btrim(location.google_place_name), '') is not null
  and nullif(btrim(location.google_match_status), '') is not null
  and nullif(btrim(cover.image_url), '') is not null
  and cover.image_url ~ '^https?://'
  and (cover.refresh_after is null or cover.refresh_after > now());

grant select on public.displayable_heritage_locations to anon, authenticated;
grant select on public.displayable_heritage_locations to service_role;
