-- Clean only the Plan/Map-owned heritage catalogue. No other module tables
-- are changed. Rows referenced by bookmarks/reviews are retained, not deleted.

-- A country name is not a Malaysian state. Recover a state when the imported
-- OSM tags contain one; otherwise store an honest empty value for later review.
update public.heritage_locations
set state = coalesce(
      nullif(btrim(osm_tags->>'addr:state'), ''),
      nullif(btrim(osm_tags->>'is_in:state'), ''),
      nullif(btrim(osm_tags->>'addr:province'), ''),
      ''
    ),
    updated_at = now()
where lower(btrim(state)) in ('malaysia', 'my', 'unknown', 'n/a');

-- Photo/geocoding providers need a non-empty location query. Coordinates stay
-- authoritative for routing; this text is a safe searchable fallback.
update public.heritage_locations
set address = concat_ws(
      ', ',
      name,
      nullif(btrim(state), ''),
      'Malaysia'
    ),
    updated_at = now()
where btrim(address) = '';

-- Deactivate likely duplicate OSM node/way representations of the same named
-- place within roughly 150 metres. Do not delete rows or cascade user data.
with ranked as (
  select
    osm_id,
    row_number() over (
      partition by
        regexp_replace(lower(btrim(name)), '[^a-z0-9]+', '', 'g'),
        round(latitude::numeric, 3),
        round(longitude::numeric, 3)
      order by
        (case when btrim(image_url) <> '' then 1 else 0 end) desc,
        (case when btrim(description) <> '' then 1 else 0 end) desc,
        length(address) desc,
        osm_id
    ) as duplicate_rank
  from public.heritage_locations
  where is_active
)
update public.heritage_locations as location
set is_active = false,
    updated_at = now()
from ranked
where location.osm_id = ranked.osm_id
  and ranked.duplicate_rank > 1;

create index if not exists heritage_locations_active_normalized_name_idx
  on public.heritage_locations (
    regexp_replace(lower(btrim(name)), '[^a-z0-9]+', '', 'g')
  )
  where is_active;
