-- Guard only the Plan/Map-owned heritage catalogue against future blank
-- addresses and duplicate active representations of the same physical place.

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
      and 6371000 * 2 * asin(
        least(
          1,
          sqrt(
            power(sin(radians(existing.latitude - new.latitude) / 2), 2) +
            cos(radians(new.latitude)) * cos(radians(existing.latitude)) *
            power(sin(radians(existing.longitude - new.longitude) / 2), 2)
          )
        )
      ) <= 200
  ) then
    new.is_active := false;
  end if;

  return new;
end;
$$;
drop trigger if exists normalize_heritage_location_before_write
  on public.heritage_locations;
create trigger normalize_heritage_location_before_write
before insert or update of name, state, address, latitude, longitude, is_active
on public.heritage_locations
for each row execute function public.normalize_heritage_location_before_write();
update public.heritage_locations
set address = concat_ws(', ', name, nullif(btrim(state), ''), 'Malaysia'),
    updated_at = now()
where btrim(address) = '';
alter table public.heritage_locations
  drop constraint if exists heritage_locations_address_not_blank;
alter table public.heritage_locations
  add constraint heritage_locations_address_not_blank
  check (btrim(address) <> '');
