-- Kinvoy — trips belong to the family.
--
-- A trip created inside a family automatically includes every family member,
-- so nobody types a second code. Marking a trip private keeps it to the
-- creator plus whoever they share the trip code with (a couples getaway the
-- kids shouldn't see). Trip codes still work for people outside the family.
-- Run after 004_family_layer.sql.

alter table public.trips
  add column family_id uuid references public.families (id) on delete set null,
  add column is_private boolean not null default false;

create index on public.trips (family_id);

-- ------------------------------------------------- create a family trip

drop function if exists public.create_trip(text, text, date, date, text, text);

create or replace function public.create_trip(
  p_name text,
  p_destination text,
  p_starts_on date,
  p_ends_on date,
  p_display_name text,
  p_kind text default 'vacation',
  p_family_id uuid default null,
  p_is_private boolean default false
)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_code text;
  v_trip trips;
  v_member members;
  v_family_id uuid;
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;
  if p_ends_on < p_starts_on then
    raise exception 'end date before start date';
  end if;

  -- Only attach to a family the caller actually belongs to.
  if p_family_id is not null and public.is_family_member(p_family_id) then
    v_family_id := p_family_id;
  else
    v_family_id := null;
  end if;

  loop
    v_code := (
      select string_agg(substr('ABCDEFGHJKLMNPQRSTUVWXYZ23456789', (floor(random() * 32) + 1)::int, 1), '')
      from generate_series(1, 6)
    );
    exit when not exists (select 1 from trips where invite_code = v_code)
      and not exists (select 1 from families where invite_code = v_code);
  end loop;

  insert into trips (name, destination, starts_on, ends_on, invite_code, created_by, kind, family_id, is_private)
  values (trim(p_name), trim(p_destination), p_starts_on, p_ends_on, v_code, auth.uid(),
          coalesce(p_kind, 'vacation'), v_family_id, coalesce(p_is_private, false))
  returning * into v_trip;

  insert into members (trip_id, user_id, display_name)
  values (v_trip.id, auth.uid(), trim(p_display_name))
  returning * into v_member;

  -- Shared family trip: everyone in the family is already on it.
  if v_family_id is not null and not coalesce(p_is_private, false) then
    insert into members (trip_id, user_id, display_name)
    select v_trip.id, fm.user_id, fm.display_name
    from family_members fm
    where fm.family_id = v_family_id
      and fm.user_id <> auth.uid()
    on conflict (trip_id, user_id) do nothing;
  end if;

  return json_build_object('trip', row_to_json(v_trip), 'member', row_to_json(v_member));
end;
$$;

-- ------------------------------ joining a family joins its shared trips

create or replace function public.join_family(
  p_code text,
  p_display_name text
)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_family families;
  v_member family_members;
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;

  select * into v_family from families where invite_code = upper(trim(p_code));
  if not found then
    raise exception 'invalid invite code';
  end if;

  insert into family_members (family_id, user_id, display_name)
  values (v_family.id, auth.uid(), trim(p_display_name))
  on conflict (family_id, user_id)
  do update set display_name = excluded.display_name
  returning * into v_member;

  -- Backfill: shared trips the family already had.
  insert into members (trip_id, user_id, display_name)
  select t.id, auth.uid(), trim(p_display_name)
  from trips t
  where t.family_id = v_family.id
    and t.is_private = false
  on conflict (trip_id, user_id) do nothing;

  return json_build_object('family', row_to_json(v_family), 'member', row_to_json(v_member));
end;
$$;
