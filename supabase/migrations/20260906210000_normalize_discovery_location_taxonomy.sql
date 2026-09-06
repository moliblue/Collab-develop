-- Discovery-only data normalization. No Mystery Journey tables are referenced.
-- Existing rows are normalized before the stricter checks are installed.

-- Earlier catalogue migrations treated every repeated normalized name as the
-- same POI. Names such as "Street Art" and "Mural" are not globally unique,
-- so restore those rows for evidence-based deduplication in the next migration.
drop index if exists public.heritage_locations_one_active_name_idx;

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
    new.address := concat_ws(', ', new.name, nullif(new.state, ''), 'Malaysia');
  end if;
  return new;
end;
$$;

update public.heritage_locations
set is_active = true,
    updated_at = now()
where not is_active;

update public.heritage_locations
set category = case
  when category = 'Temple & Sacred' then
    case
      when coalesce(osm_tags::text, '') ~* '(historic|heritage)'
        then 'Traditional Heritage Site'
      else 'Cultural Heritage'
    end
  when category = 'Archaeological Site' then
    case
      when concat_ws(' ', name, description, coalesce(osm_tags::text, ''))
        ~* '(traditional|settlement|kampung|longhouse)'
        then 'Traditional Heritage Site'
      else 'Historical Monument'
    end
  else category
end
where category in ('Temple & Sacred', 'Archaeological Site');

alter table public.heritage_locations
  drop constraint if exists heritage_locations_category_check;

alter table public.heritage_locations
  add constraint heritage_locations_category_check
  check (category in (
    'Cultural Heritage',
    'Museum',
    'Historical Monument',
    'Traditional Heritage Site',
    'Natural Heritage'
  ));

alter table public.heritage_locations
  drop constraint if exists heritage_locations_google_match_status_check;

alter table public.heritage_locations
  add constraint heritage_locations_google_match_status_check
  check (
    google_match_status is null
    or google_match_status in ('exact', 'high_confidence', 'nearby')
  );

alter table public.heritage_locations
  add constraint heritage_locations_state_check
  check (
    state is null
    or btrim(state) = ''
    or state in (
      'Johor', 'Kedah', 'Kelantan', 'Melaka', 'Negeri Sembilan',
      'Pahang', 'Penang', 'Perak', 'Perlis', 'Sabah', 'Sarawak',
      'Selangor', 'Terengganu', 'Kuala Lumpur', 'Putrajaya', 'Labuan'
    )
  );

comment on constraint heritage_locations_category_check
  on public.heritage_locations is
  'Discovery experience categories; kept aligned with Flutter filters.';

comment on constraint heritage_locations_state_check
  on public.heritage_locations is
  'Canonical Malaysian states and Federal Territories for Discovery.';
