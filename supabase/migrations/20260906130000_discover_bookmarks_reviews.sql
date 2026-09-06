-- UC201 Discover persistence. This migration deliberately reuses the stable
-- Map-owned heritage_locations.osm_id catalogue key.
create table if not exists public.bookmarks (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  destination_id text not null references public.heritage_locations(osm_id) on delete cascade,
  destination_name text not null,
  destination_category text,
  destination_latitude double precision,
  destination_longitude double precision,
  destination_photo_url text,
  created_at timestamptz not null default now(),
  unique (user_id, destination_id)
);

create index if not exists bookmarks_user_created_idx
  on public.bookmarks (user_id, created_at desc);

alter table public.bookmarks enable row level security;
create policy "users read own bookmarks" on public.bookmarks
  for select to authenticated using ((select auth.uid()) = user_id);
create policy "users add own bookmarks" on public.bookmarks
  for insert to authenticated with check ((select auth.uid()) = user_id);
create policy "users delete own bookmarks" on public.bookmarks
  for delete to authenticated using ((select auth.uid()) = user_id);

grant select, insert, delete on public.bookmarks to authenticated;
revoke all on public.bookmarks from anon;

create table if not exists public.destination_reviews (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  destination_id text not null references public.heritage_locations(osm_id) on delete cascade,
  rating integer not null check (rating between 1 and 5),
  review_text text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists destination_reviews_destination_created_idx
  on public.destination_reviews (destination_id, created_at desc);
create index if not exists destination_reviews_user_idx
  on public.destination_reviews (user_id);

alter table public.destination_reviews enable row level security;
create policy "authenticated users read destination reviews"
  on public.destination_reviews for select to authenticated using (true);
create policy "users submit own destination reviews"
  on public.destination_reviews for insert to authenticated
  with check ((select auth.uid()) = user_id);

grant select, insert on public.destination_reviews to authenticated;
revoke all on public.destination_reviews from anon;

comment on table public.destination_reviews is
  'UC201 ratings and optional reviews. Multiple reviews per user/location are intentionally allowed.';
