-- Complete ExploreMY UC501 registration identity data and avatar storage.
-- Authentication email/password remain managed by Supabase Auth.

alter table public.profiles
  add column if not exists phone_number text,
  add column if not exists ic_number text,
  add column if not exists birth_date date;

with candidate_identity as (
  select
    auth_user.id,
    nullif(regexp_replace(auth_user.raw_user_meta_data ->> 'phone', '\D', '', 'g'), '') as phone_number,
    nullif(regexp_replace(auth_user.raw_user_meta_data ->> 'ic', '\D', '', 'g'), '') as ic_number,
    auth_user.raw_user_meta_data ->> 'birth_date' as birth_date,
    row_number() over (
      partition by nullif(regexp_replace(auth_user.raw_user_meta_data ->> 'ic', '\D', '', 'g'), '')
      order by auth_user.created_at, auth_user.id
    ) as ic_occurrence
  from auth.users auth_user
)
update public.profiles profile
set
  phone_number = case
    when candidate.phone_number ~ '^\d{10,11}$' then candidate.phone_number
    else profile.phone_number
  end,
  ic_number = case
    when candidate.ic_number ~ '^\d{12}$' and candidate.ic_occurrence = 1
      then candidate.ic_number
    else profile.ic_number
  end,
  birth_date = case
    when candidate.birth_date ~ '^\d{4}-\d{2}-\d{2}$'
      then to_date(candidate.birth_date, 'YYYY-MM-DD')
    else profile.birth_date
  end
from candidate_identity candidate
where profile.id = candidate.id;

alter table public.profiles
  drop constraint if exists profiles_phone_number_check,
  drop constraint if exists profiles_ic_number_check;

alter table public.profiles
  add constraint profiles_phone_number_check
    check (phone_number is null or phone_number ~ '^\d{10,11}$'),
  add constraint profiles_ic_number_check
    check (ic_number is null or ic_number ~ '^\d{12}$');

create unique index if not exists profiles_ic_number_unique
  on public.profiles (ic_number)
  where ic_number is not null;

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
  if supplied_phone !~ '^\d{10,11}$' then supplied_phone := null; end if;
  if supplied_ic !~ '^\d{12}$' then supplied_ic := null; end if;

  if supplied_ic is not null and exists (
    select 1 from public.profiles profile where profile.ic_number = supplied_ic
  ) then
    raise unique_violation using message = 'IC number is already registered';
  end if;

  begin
    supplied_birth_date := (new.raw_user_meta_data ->> 'birth_date')::date;
  exception when others then
    supplied_birth_date := null;
  end;

  insert into public.profiles (
    id,
    username,
    full_name,
    phone_number,
    ic_number,
    birth_date
  )
  values (
    new.id,
    new.raw_user_meta_data ->> 'username',
    coalesce(
      new.raw_user_meta_data ->> 'full_name',
      new.raw_user_meta_data ->> 'display_name'
    ),
    supplied_phone,
    supplied_ic,
    supplied_birth_date
  )
  on conflict (id) do update set
    full_name = coalesce(excluded.full_name, public.profiles.full_name),
    phone_number = coalesce(excluded.phone_number, public.profiles.phone_number),
    ic_number = coalesce(excluded.ic_number, public.profiles.ic_number),
    birth_date = coalesce(excluded.birth_date, public.profiles.birth_date);

  return new;
end;
$$;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'avatars',
  'avatars',
  false,
  5242880,
  array['image/jpeg', 'image/png']
)
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "Users can read own avatar" on storage.objects;
create policy "Users can read own avatar"
on storage.objects for select
to authenticated
using (
  bucket_id = 'avatars'
  and (storage.foldername(name))[1] = auth.uid()::text
);

drop policy if exists "Users can upload own avatar" on storage.objects;
create policy "Users can upload own avatar"
on storage.objects for insert
to authenticated
with check (
  bucket_id = 'avatars'
  and (storage.foldername(name))[1] = auth.uid()::text
);

drop policy if exists "Users can update own avatar" on storage.objects;
create policy "Users can update own avatar"
on storage.objects for update
to authenticated
using (
  bucket_id = 'avatars'
  and (storage.foldername(name))[1] = auth.uid()::text
)
with check (
  bucket_id = 'avatars'
  and (storage.foldername(name))[1] = auth.uid()::text
);

drop policy if exists "Users can delete own avatar" on storage.objects;
create policy "Users can delete own avatar"
on storage.objects for delete
to authenticated
using (
  bucket_id = 'avatars'
  and (storage.foldername(name))[1] = auth.uid()::text
);
