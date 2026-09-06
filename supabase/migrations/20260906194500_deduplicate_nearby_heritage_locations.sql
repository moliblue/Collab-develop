-- Remove remaining duplicate representations of the same named physical place.
-- This uses actual coordinate distance instead of coordinate grid rounding, so
-- duplicates on opposite sides of a rounding boundary are handled correctly.
-- Rows are retained for referential integrity and only made inactive.

with candidates as (
  select
    location.osm_id,
    location.name,
    location.latitude,
    location.longitude,
    location.image_url,
    location.description,
    location.address,
    location.is_verified,
    regexp_replace(lower(btrim(location.name)), '[^a-z0-9]+', '', 'g')
      as normalized_name,
    (
      case when location.is_verified then 16 else 0 end +
      case when btrim(location.image_url) <> '' then 8 else 0 end +
      case when btrim(location.description) <> '' then 4 else 0 end +
      case when btrim(location.address) <> '' then 2 else 0 end +
      case when location.osm_id like 'seed/%' then 1 else 0 end
    ) as quality
  from public.heritage_locations as location
  where location.is_active
), duplicate_losers as (
  select distinct weaker.osm_id
  from candidates as weaker
  join candidates as stronger
    on stronger.normalized_name = weaker.normalized_name
   and stronger.osm_id <> weaker.osm_id
   and 6371000 * 2 * asin(
     least(
       1,
       sqrt(
         power(sin(radians(stronger.latitude - weaker.latitude) / 2), 2) +
         cos(radians(weaker.latitude)) * cos(radians(stronger.latitude)) *
         power(sin(radians(stronger.longitude - weaker.longitude) / 2), 2)
       )
     )
   ) <= 200
   and (
     stronger.quality > weaker.quality or
     (stronger.quality = weaker.quality and stronger.osm_id < weaker.osm_id)
   )
)
update public.heritage_locations as location
set is_active = false,
    updated_at = now()
from duplicate_losers
where location.osm_id = duplicate_losers.osm_id;

