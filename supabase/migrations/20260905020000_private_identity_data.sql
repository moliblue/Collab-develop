-- Keep sensitive UC501 registration data separate from collaborative profiles.

create table if not exists public.user_private_profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  phone_number text not null check (phone_number ~ '^\d{10,11}$'),
  ic_number text not null unique check (ic_number ~ '^\d{12}$'),
  birth_date date not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.user_private_profiles enable row level security;

drop policy if exists "Users can read own private profile"
on public.user_private_profiles;
create policy "Users can read own private profile"
on public.user_private_profiles for select
to authenticated
using (user_id = auth.uid());

drop policy if exists "Users can update own private profile"
on public.user_private_profiles;
create policy "Users can update own private profile"
on public.user_private_profiles for update
to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

insert into public.user_private_profiles (
  user_id,
  phone_number,
  ic_number,
  birth_date
)
select id, phone_number, ic_number, birth_date
from public.profiles
where phone_number is not null
  and ic_number is not null
  and birth_date is not null
on conflict (user_id) do update set
  phone_number = excluded.phone_number,
  ic_number = excluded.ic_number,
  birth_date = excluded.birth_date,
  updated_at = now();

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  supplied_phone text := regexp_replace(
    coalesce(new.raw_user_meta_data ->> 'phone', ''), '\D', '', 'g'
  );
  supplied_ic text := regexp_replace(
    coalesce(new.raw_user_meta_data ->> 'ic', ''), '\D', '', 'g'
  );
  supplied_birth_date date;
begin
  if supplied_phone !~ '^\d{10,11}$'
    or supplied_ic !~ '^\d{12}$'
  then
    raise check_violation using message = 'Invalid identity/contact format';
  end if;

  begin
    supplied_birth_date := (new.raw_user_meta_data ->> 'birth_date')::date;
  exception when others then
    raise check_violation using message = 'Invalid birthday format';
  end;

  if exists (
    select 1
    from public.user_private_profiles private_profile
    where private_profile.ic_number = supplied_ic
  ) then
    raise unique_violation using message = 'IC number is already registered';
  end if;

  insert into public.profiles (id, username, full_name)
  values (
    new.id,
    new.raw_user_meta_data ->> 'username',
    coalesce(
      new.raw_user_meta_data ->> 'full_name',
      new.raw_user_meta_data ->> 'display_name'
    )
  )
  on conflict (id) do update set
    full_name = coalesce(excluded.full_name, public.profiles.full_name);

  insert into public.user_private_profiles (
    user_id,
    phone_number,
    ic_number,
    birth_date
  ) values (
    new.id,
    supplied_phone,
    supplied_ic,
    supplied_birth_date
  );

  return new;
end;
$$;

alter table public.profiles
  drop column if exists phone_number,
  drop column if exists ic_number,
  drop column if exists birth_date;
