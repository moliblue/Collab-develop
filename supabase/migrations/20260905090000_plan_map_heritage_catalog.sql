-- Plan/Map module-owned, read-only catalogue. This migration does not alter
-- tables belonging to other modules.
create table if not exists public.heritage_locations (
  osm_id text primary key,
  name text not null,
  category text not null check (category in (
    'Archaeological Site', 'Cultural Heritage', 'Historical Monument',
    'Museum', 'Natural Heritage', 'Temple & Sacred', 'Traditional Heritage Site'
  )),
  state text not null,
  address text not null default '',
  description text not null default '',
  latitude double precision not null check (latitude between -90 and 90),
  longitude double precision not null check (longitude between -180 and 180),
  image_url text not null default '',
  opening_hours text not null default '',
  osm_tags jsonb not null default '{}'::jsonb,
  is_verified boolean not null default true,
  is_active boolean not null default true,
  source_updated_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists heritage_locations_coordinates_idx
  on public.heritage_locations (latitude, longitude) where is_active;
create index if not exists heritage_locations_name_idx
  on public.heritage_locations using gin (to_tsvector('simple', name || ' ' || address || ' ' || state));

alter table public.heritage_locations enable row level security;
drop policy if exists "heritage catalogue is publicly readable" on public.heritage_locations;
create policy "heritage catalogue is publicly readable"
  on public.heritage_locations for select
  to anon, authenticated
  using (is_active and is_verified);

grant select on public.heritage_locations to anon, authenticated;
revoke insert, update, delete on public.heritage_locations from anon, authenticated;

comment on table public.heritage_locations is
  'Verified Malaysian heritage catalogue owned by the Plan and Map modules; OSM is the runtime fallback.';

-- Stable starter catalogue. Administrators can expand it using verified OSM
-- records without granting catalogue writes to application users.
insert into public.heritage_locations
  (osm_id, name, category, state, address, description, latitude, longitude, osm_tags)
values
  ('seed/batu-caves', 'Batu Caves Murugan Temple', 'Temple & Sacred', 'Selangor', 'Gombak, 68100 Batu Caves, Selangor', 'Hindu temple complex set within limestone caves.', 3.2379, 101.6840, '{"historic":"religious","heritage":"yes"}'),
  ('seed/sultan-abdul-samad', 'Sultan Abdul Samad Building', 'Historical Monument', 'Kuala Lumpur', 'Jalan Raja, Kuala Lumpur', 'Landmark nineteenth-century civic building facing Merdeka Square.', 3.1488, 101.6942, '{"historic":"building"}'),
  ('seed/merdeka-square', 'Dataran Merdeka', 'Historical Monument', 'Kuala Lumpur', 'Jalan Raja, Kuala Lumpur', 'Historic square associated with Malaysian independence.', 3.1478, 101.6937, '{"historic":"memorial"}'),
  ('seed/national-museum', 'National Museum of Malaysia', 'Museum', 'Kuala Lumpur', 'Jalan Damansara, Kuala Lumpur', 'National museum presenting Malaysian history and culture.', 3.1379, 101.6871, '{"tourism":"museum"}'),
  ('seed/islamic-arts-museum', 'Islamic Arts Museum Malaysia', 'Museum', 'Kuala Lumpur', 'Jalan Lembah Perdana, Kuala Lumpur', 'Museum dedicated to Islamic decorative arts and material culture.', 3.1413, 101.6896, '{"tourism":"museum"}'),
  ('seed/cheong-fatt-tze', 'Cheong Fatt Tze Blue Mansion', 'Traditional Heritage Site', 'Penang', '14 Leith Street, George Town, Penang', 'Restored indigo-blue courtyard mansion in George Town.', 5.4213, 100.3352, '{"historic":"manor","heritage":"yes"}'),
  ('seed/khoo-kongsi', 'Leong San Tong Khoo Kongsi', 'Traditional Heritage Site', 'Penang', '18 Cannon Square, George Town, Penang', 'Historic Chinese clanhouse and temple complex.', 5.4145, 100.3389, '{"historic":"building","amenity":"place_of_worship"}'),
  ('seed/fort-cornwallis', 'Fort Cornwallis', 'Historical Monument', 'Penang', 'Jalan Tun Syed Sheh Barakbah, George Town, Penang', 'Eighteenth-century star fort in George Town.', 5.4205, 100.3442, '{"historic":"fort"}'),
  ('seed/penang-peranakan', 'Pinang Peranakan Mansion', 'Museum', 'Penang', '29 Church Street, George Town, Penang', 'Museum of Peranakan heritage in a historic mansion.', 5.4174, 100.3414, '{"tourism":"museum","historic":"manor"}'),
  ('seed/cheng-hoon-teng', 'Cheng Hoon Teng Temple', 'Temple & Sacred', 'Melaka', '25 Jalan Tokong, Melaka', 'Malaysia’s oldest functioning Chinese temple.', 2.1975, 102.2467, '{"amenity":"place_of_worship","historic":"building"}'),
  ('seed/a-famosa', 'A Famosa', 'Archaeological Site', 'Melaka', 'Jalan Parameswara, Bandar Hilir, Melaka', 'Surviving gateway of a sixteenth-century Portuguese fortress.', 2.1917, 102.2503, '{"historic":"ruins"}'),
  ('seed/stadthuys', 'The Stadthuys', 'Museum', 'Melaka', 'Bandar Hilir, Melaka', 'Historic Dutch administrative building and museum complex.', 2.1944, 102.2495, '{"historic":"building","tourism":"museum"}'),
  ('seed/st-pauls-hill', 'Saint Paul’s Church Ruins', 'Archaeological Site', 'Melaka', 'Saint Paul’s Hill, Bandar Hilir, Melaka', 'Ruins of a sixteenth-century church overlooking Melaka.', 2.1927, 102.2492, '{"historic":"ruins"}'),
  ('seed/kinabalu-park', 'Kinabalu Park', 'Natural Heritage', 'Sabah', 'Ranau, Sabah', 'UNESCO-listed protected landscape surrounding Mount Kinabalu.', 6.0750, 116.5587, '{"boundary":"national_park","heritage":"world_heritage_site"}'),
  ('seed/gunung-mulu', 'Gunung Mulu National Park', 'Natural Heritage', 'Sarawak', 'Miri Division, Sarawak', 'UNESCO-listed karst landscape and cave system.', 4.0481, 114.8124, '{"boundary":"national_park","heritage":"world_heritage_site"}'),
  ('seed/niah-caves', 'Niah National Park and Caves', 'Archaeological Site', 'Sarawak', 'Niah, Miri Division, Sarawak', 'Cave complex with major prehistoric archaeological evidence.', 3.8140, 113.7810, '{"natural":"cave_entrance","historic":"archaeological_site"}')
on conflict (osm_id) do update set
  name = excluded.name,
  category = excluded.category,
  state = excluded.state,
  address = excluded.address,
  description = excluded.description,
  latitude = excluded.latitude,
  longitude = excluded.longitude,
  osm_tags = excluded.osm_tags,
  updated_at = now();
