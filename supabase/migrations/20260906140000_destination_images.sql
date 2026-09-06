-- Discovery destination images. Discovery is backed by heritage_locations,
-- whose stable catalogue key is osm_id (text), rather than the separate
-- Mystery destinations.id (uuid).
create table public.destination_images (
  id uuid primary key default gen_random_uuid(),
  destination_id text not null
    references public.heritage_locations(osm_id) on delete cascade,
  image_url text not null check (btrim(image_url) <> ''),
  source text not null default 'pexels',
  source_image_id text,
  photographer_name text,
  photographer_url text,
  is_cover boolean not null default false,
  display_order integer not null default 1
    check (display_order between 1 and 3),
  match_status text not null default 'auto',
  created_at timestamptz not null default now(),
  unique (destination_id, display_order)
);
create index destination_images_destination_idx
  on public.destination_images (destination_id);
create unique index destination_images_one_cover_idx
  on public.destination_images (destination_id)
  where is_cover;
create unique index destination_images_source_identity_idx
  on public.destination_images (source, source_image_id)
  where source_image_id is not null;
alter table public.destination_images enable row level security;
create policy "destination images follow public heritage catalogue"
  on public.destination_images for select
  to anon, authenticated
  using (
    exists (
      select 1
      from public.heritage_locations location
      where location.osm_id = destination_images.destination_id
        and location.is_active
        and location.is_verified
    )
  );
grant select on public.destination_images to anon, authenticated;
grant select, insert, update, delete on public.destination_images
  to service_role;
revoke insert, update, delete on public.destination_images
  from anon, authenticated;
-- One-row-per-destination read model for Discovery cards. security_invoker
-- keeps the destination_images RLS policy authoritative.
create view public.destination_image_covers
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
  display_order
from public.destination_images
order by destination_id, is_cover desc, display_order asc, id asc;
grant select on public.destination_image_covers to anon, authenticated;
grant select on public.destination_image_covers to service_role;
comment on table public.destination_images is
  'Up to three curated images for each Discovery heritage location.';
comment on view public.destination_image_covers is
  'Cover image per Discovery destination, falling back to lowest display order.';
