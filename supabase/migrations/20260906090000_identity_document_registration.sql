-- Generalize private registration identity from Malaysian IC-only to one
-- normalized IC or passport document. Existing private profile rows are
-- preserved and backfilled. The legacy IC column remains as a constrained,
-- nullable compatibility mirror during phase 1.

alter table public.user_private_profiles
  add column if not exists identity_type text,
  add column if not exists identity_number text,
  add column if not exists issuing_country text;

update public.user_private_profiles
set
  identity_type = 'ic',
  identity_number = ic_number,
  issuing_country = 'MY'
where identity_type is null
   or identity_number is null
   or issuing_country is null;

do $$
begin
  if exists (
    select 1
    from public.user_private_profiles
    where identity_type is null
       or identity_number is null
       or issuing_country is null
  ) then
    raise exception 'Identity backfill left null values';
  end if;

  if exists (
    select 1
    from public.user_private_profiles
    where identity_type <> 'ic'
       or issuing_country <> 'MY'
       or identity_number !~ '^\d{12}$'
  ) then
    raise exception 'Existing IC identity data is invalid';
  end if;

  if exists (
    select 1
    from public.user_private_profiles
    group by identity_type, issuing_country, identity_number
    having count(*) > 1
  ) then
    raise exception 'Duplicate identity documents prevent migration';
  end if;
end;
$$;

alter table public.user_private_profiles
  alter column identity_type set not null,
  alter column identity_number set not null,
  alter column issuing_country set not null,
  alter column ic_number drop not null;

alter table public.user_private_profiles
  add constraint user_private_profiles_identity_type_check
    check (identity_type in ('ic', 'passport')),
  add constraint user_private_profiles_identity_country_check
    check (issuing_country ~ '^[A-Z]{2}$'),
  add constraint user_private_profiles_identity_format_check
    check (
      (
        identity_type = 'ic'
        and issuing_country = 'MY'
        and identity_number ~ '^\d{12}$'
      )
      or
      (
        identity_type = 'passport'
        and identity_number ~ '^[A-Z0-9]{5,20}$'
      )
    ),
  add constraint user_private_profiles_legacy_ic_consistency_check
    check (
      (identity_type = 'ic' and ic_number = identity_number)
      or (identity_type = 'passport' and ic_number is null)
    ),
  add constraint user_private_profiles_identity_unique
    unique (identity_type, issuing_country, identity_number);

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
  supplied_identity_type text := lower(coalesce(
    nullif(trim(new.raw_user_meta_data ->> 'identity_type'), ''),
    case
      when nullif(trim(new.raw_user_meta_data ->> 'ic'), '') is not null
        then 'ic'
      else ''
    end
  ));
  supplied_identity_number text;
  supplied_country text;
  supplied_birth_date date;
begin
  if supplied_identity_type not in ('ic', 'passport') then
    raise check_violation using message = 'Invalid identity type';
  end if;

  supplied_identity_number := upper(regexp_replace(
    coalesce(
      nullif(new.raw_user_meta_data ->> 'identity_number', ''),
      new.raw_user_meta_data ->> 'ic',
      ''
    ),
    '[[:space:]-]',
    '',
    'g'
  ));
  supplied_country := upper(trim(coalesce(
    nullif(new.raw_user_meta_data ->> 'issuing_country', ''),
    case when supplied_identity_type = 'ic' then 'MY' else '' end
  )));

  if supplied_phone !~ '^\d{10,11}$' then
    raise check_violation using message = 'Invalid contact format';
  end if;

  if supplied_identity_type = 'ic' and (
    supplied_country <> 'MY' or supplied_identity_number !~ '^\d{12}$'
  ) then
    raise check_violation using message = 'Invalid Malaysian IC identity';
  end if;

  if supplied_identity_type = 'passport' and (
    supplied_country !~ '^[A-Z]{2}$'
    or supplied_identity_number !~ '^[A-Z0-9]{5,20}$'
  ) then
    raise check_violation using message = 'Invalid passport identity';
  end if;

  begin
    supplied_birth_date := (new.raw_user_meta_data ->> 'birth_date')::date;
  exception when others then
    raise check_violation using message = 'Invalid birthday format';
  end;

  if exists (
    select 1
    from public.user_private_profiles private_profile
    where private_profile.identity_type = supplied_identity_type
      and private_profile.issuing_country = supplied_country
      and private_profile.identity_number = supplied_identity_number
  ) then
    raise unique_violation
      using message = 'Identification number is already registered',
            constraint = 'user_private_profiles_identity_unique';
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
    identity_type,
    identity_number,
    issuing_country,
    birth_date
  ) values (
    new.id,
    supplied_phone,
    case
      when supplied_identity_type = 'ic' then supplied_identity_number
      else null
    end,
    supplied_identity_type,
    supplied_identity_number,
    supplied_country,
    supplied_birth_date
  );

  return new;
end;
$$;
