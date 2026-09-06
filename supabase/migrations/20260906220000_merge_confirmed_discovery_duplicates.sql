-- Merge only conservatively confirmed duplicate Discovery POIs. Generic names
-- and nearby individual artworks remain separate. All dependent Discovery
-- references are migrated before a duplicate catalogue row is deleted.

do $$
declare
  pair record;
  best_image_id uuid;
begin
  for pair in
    select * from (values
      ('node/1524273574',  'way/604943238'),
      ('node/4561190691',  'node/4561671002'),
      ('node/4870445676',  'way/620961107'),
      ('node/4870445676',  'way/620961108'),
      ('node/4870445676',  'way/620961109'),
      ('node/4870445676',  'way/620961110'),
      ('node/4870445676',  'way/620961111'),
      ('way/740866547',    'node/6994428885'),
      ('node/7441496669',  'way/974969460'),
      ('relation/12433499','seed/penang-peranakan'),
      ('relation/8530141', 'relation/9627247'),
      ('relation/8530141', 'way/616822440'),
      ('node/9328895193',  'node/9328905632')
    ) as confirmed(canonical_id, duplicate_id)
  loop
    if not exists (
      select 1 from public.heritage_locations
      where osm_id = pair.canonical_id
    ) or not exists (
      select 1 from public.heritage_locations
      where osm_id = pair.duplicate_id
    ) then
      continue;
    end if;

    update public.heritage_locations as canonical
    set
      address = case
        when length(duplicate.address) > length(canonical.address)
          then duplicate.address else canonical.address end,
      description = case
        when length(duplicate.description) > length(canonical.description)
          then duplicate.description else canonical.description end,
      image_url = coalesce(nullif(canonical.image_url, ''), duplicate.image_url),
      opening_hours = coalesce(
        nullif(canonical.opening_hours, ''), duplicate.opening_hours
      ),
      osm_tags = coalesce(duplicate.osm_tags, '{}'::jsonb) ||
        coalesce(canonical.osm_tags, '{}'::jsonb),
      is_verified = canonical.is_verified or duplicate.is_verified,
      is_active = canonical.is_active or duplicate.is_active,
      source_updated_at = greatest(
        canonical.source_updated_at, duplicate.source_updated_at
      ),
      created_at = least(canonical.created_at, duplicate.created_at),
      updated_at = now(),
      google_place_id = coalesce(
        canonical.google_place_id, duplicate.google_place_id
      ),
      google_place_name = coalesce(
        canonical.google_place_name, duplicate.google_place_name
      ),
      google_match_status = coalesce(
        canonical.google_match_status, duplicate.google_match_status
      ),
      formatted_address = case
        when length(coalesce(duplicate.formatted_address, '')) >
             length(coalesce(canonical.formatted_address, ''))
          then duplicate.formatted_address else canonical.formatted_address end,
      opening_hours_weekday_text = coalesce(
        canonical.opening_hours_weekday_text,
        duplicate.opening_hours_weekday_text
      ),
      opening_hours_periods = coalesce(
        canonical.opening_hours_periods,
        duplicate.opening_hours_periods
      ),
      opening_hours_updated_at = greatest(
        canonical.opening_hours_updated_at,
        duplicate.opening_hours_updated_at
      ),
      google_maps_uri = coalesce(
        canonical.google_maps_uri, duplicate.google_maps_uri
      )
    from public.heritage_locations as duplicate
    where canonical.osm_id = pair.canonical_id
      and duplicate.osm_id = pair.duplicate_id;

    select image.id
    into best_image_id
    from public.destination_images as image
    where image.destination_id in (pair.canonical_id, pair.duplicate_id)
    order by
      case image.match_status
        when 'manual' then 7
        when 'verified' then 6
        when 'exact' then 5
        when 'high_confidence' then 4
        when 'nearby' then 3
        when 'auto' then 2
        else 1
      end desc,
      case image.source
        when 'wikimedia' then 4
        when 'google_places' then 3
        when 'manual' then 2
        else 1
      end desc,
      image.is_cover desc,
      image.display_order,
      image.created_at
    limit 1;

    if best_image_id is not null then
      delete from public.destination_images
      where destination_id in (pair.canonical_id, pair.duplicate_id)
        and id <> best_image_id;

      update public.destination_images
      set destination_id = pair.canonical_id,
          is_cover = true,
          display_order = 1
      where id = best_image_id;
    end if;

    delete from public.bookmarks as duplicate_bookmark
    where duplicate_bookmark.destination_id = pair.duplicate_id
      and exists (
        select 1 from public.bookmarks as canonical_bookmark
        where canonical_bookmark.user_id = duplicate_bookmark.user_id
          and canonical_bookmark.destination_id = pair.canonical_id
      );

    update public.bookmarks
    set destination_id = pair.canonical_id
    where destination_id = pair.duplicate_id;

    update public.destination_reviews
    set destination_id = pair.canonical_id
    where destination_id = pair.duplicate_id;

    delete from public.heritage_locations
    where osm_id = pair.duplicate_id;
  end loop;
end;
$$;
