-- The product requires one active heritage catalogue row per normalized name.
-- Duplicate rows remain stored for audit and referential integrity, but are
-- deactivated so they are not returned to Discover, Map, or Plan.

with ranked as (
  select
    osm_id,
    row_number() over (
      partition by regexp_replace(lower(btrim(name)), '[^a-z0-9]+', '', 'g')
      order by
        (case when is_verified then 1 else 0 end) desc,
        (case when btrim(image_url) <> '' then 1 else 0 end) desc,
        (case when google_place_id is not null then 1 else 0 end) desc,
        (case when btrim(description) <> '' then 1 else 0 end) desc,
        (case when btrim(state) <> '' then 1 else 0 end) desc,
        length(address) desc,
        (case when osm_id like 'seed/%' then 1 else 0 end) desc,
        osm_id
    ) as name_rank
  from public.heritage_locations
  where is_active
)
update public.heritage_locations as location
set is_active = false,
    updated_at = now()
from ranked
where location.osm_id = ranked.osm_id
  and ranked.name_rank > 1;

drop index if exists public.heritage_locations_one_active_name_idx;
create unique index heritage_locations_one_active_name_idx
  on public.heritage_locations (
    regexp_replace(lower(btrim(name)), '[^a-z0-9]+', '', 'g')
  )
  where is_active;

-- Future imports with an already-active normalized name are retained as
-- inactive records instead of creating another visible duplicate.
create or replace function public.normalize_heritage_location_before_write()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.name := btrim(new.name);
  new.state := btrim(coalesce(new.state, ''));
  new.address := btrim(coalesce(new.address, ''));

  if new.address = '' then
    new.address := concat_ws(
      ', ',
      new.name,
      nullif(new.state, ''),
      'Malaysia'
    );
  end if;

  if new.is_active and exists (
    select 1
    from public.heritage_locations as existing
    where existing.is_active
      and existing.osm_id <> new.osm_id
      and regexp_replace(lower(btrim(existing.name)), '[^a-z0-9]+', '', 'g') =
          regexp_replace(lower(new.name), '[^a-z0-9]+', '', 'g')
  ) then
    new.is_active := false;
  end if;

  return new;
end;
$$;

