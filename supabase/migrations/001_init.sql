-- Getaway — initial schema
-- Run this in the Supabase SQL editor (or `supabase db push`).
-- Design note: a "trip" is really an event workspace (dates + members +
-- chat + calendar + locations + info), which is what lets this app grow
-- into the broader Family Hub roadmap without a schema rewrite.

create extension if not exists pgcrypto;

-- ---------------------------------------------------------------- tables

create table public.trips (
  id          uuid primary key default gen_random_uuid(),
  name        text not null,
  destination text not null,
  starts_on   date not null,
  ends_on     date not null check (ends_on >= starts_on),
  invite_code text not null unique,
  created_by  uuid not null references auth.users (id),
  created_at  timestamptz not null default now()
);

create table public.members (
  id           uuid primary key default gen_random_uuid(),
  trip_id      uuid not null references public.trips (id) on delete cascade,
  user_id      uuid not null references auth.users (id),
  display_name text not null,
  joined_at    timestamptz not null default now(),
  unique (trip_id, user_id)
);

create table public.events (
  id            uuid primary key default gen_random_uuid(),
  trip_id       uuid not null references public.trips (id) on delete cascade,
  member_id     uuid not null references public.members (id) on delete cascade,
  title         text not null,
  notes         text,
  location_name text,
  starts_at     timestamptz not null,
  ends_at       timestamptz,
  created_at    timestamptz not null default now()
);

create table public.messages (
  id         uuid primary key default gen_random_uuid(),
  trip_id    uuid not null references public.trips (id) on delete cascade,
  member_id  uuid not null references public.members (id) on delete cascade,
  content    text not null check (char_length(content) <= 4000),
  created_at timestamptz not null default now()
);

-- One row per member, upserted as they move. Deleted when sharing stops.
create table public.locations (
  member_id  uuid primary key references public.members (id) on delete cascade,
  trip_id    uuid not null references public.trips (id) on delete cascade,
  latitude   double precision not null,
  longitude  double precision not null,
  updated_at timestamptz not null default now()
);

-- Flights, lodging, rental cars, tickets, misc.
create table public.logistics (
  id         uuid primary key default gen_random_uuid(),
  trip_id    uuid not null references public.trips (id) on delete cascade,
  member_id  uuid not null references public.members (id) on delete cascade,
  kind       text not null check (kind in ('flight', 'hotel', 'car', 'ticket', 'other')),
  title      text not null,
  details    text,
  happens_on date,
  created_at timestamptz not null default now()
);

create index on public.members (trip_id);
create index on public.events (trip_id, starts_at);
create index on public.messages (trip_id, created_at);
create index on public.locations (trip_id);
create index on public.logistics (trip_id);

-- ------------------------------------------------------------- helpers

-- SECURITY DEFINER so policies can check membership without recursing
-- into the members table's own RLS.
create or replace function public.is_trip_member(t uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1 from public.members
    where trip_id = t and user_id = auth.uid()
  );
$$;

create or replace function public.my_member_ids()
returns setof uuid
language sql
security definer
set search_path = public
stable
as $$
  select id from public.members where user_id = auth.uid();
$$;

-- ------------------------------------------------------ create / join

-- Trip creation and joining go through SECURITY DEFINER functions so
-- clients never need direct insert access to trips, and invite-code
-- lookup works before the caller is a member.

create or replace function public.create_trip(
  p_name text,
  p_destination text,
  p_starts_on date,
  p_ends_on date,
  p_display_name text
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
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;
  if p_ends_on < p_starts_on then
    raise exception 'end date before start date';
  end if;

  -- 6 chars, skipping ambiguous 0/O/1/I; retry on the rare collision.
  loop
    v_code := (
      select string_agg(substr('ABCDEFGHJKLMNPQRSTUVWXYZ23456789', (floor(random() * 32) + 1)::int, 1), '')
      from generate_series(1, 6)
    );
    exit when not exists (select 1 from trips where invite_code = v_code);
  end loop;

  insert into trips (name, destination, starts_on, ends_on, invite_code, created_by)
  values (trim(p_name), trim(p_destination), p_starts_on, p_ends_on, v_code, auth.uid())
  returning * into v_trip;

  insert into members (trip_id, user_id, display_name)
  values (v_trip.id, auth.uid(), trim(p_display_name))
  returning * into v_member;

  return json_build_object('trip', row_to_json(v_trip), 'member', row_to_json(v_member));
end;
$$;

create or replace function public.join_trip(
  p_code text,
  p_display_name text
)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_trip trips;
  v_member members;
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;

  select * into v_trip from trips where invite_code = upper(trim(p_code));
  if not found then
    raise exception 'invalid invite code';
  end if;

  insert into members (trip_id, user_id, display_name)
  values (v_trip.id, auth.uid(), trim(p_display_name))
  on conflict (trip_id, user_id)
  do update set display_name = excluded.display_name
  returning * into v_member;

  return json_build_object('trip', row_to_json(v_trip), 'member', row_to_json(v_member));
end;
$$;

-- ----------------------------------------------------------------- RLS

alter table public.trips enable row level security;
alter table public.members enable row level security;
alter table public.events enable row level security;
alter table public.messages enable row level security;
alter table public.locations enable row level security;
alter table public.logistics enable row level security;

create policy "members can read their trips"
  on public.trips for select
  using (public.is_trip_member(id));

create policy "members can read the roster"
  on public.members for select
  using (public.is_trip_member(trip_id));

create policy "members can leave"
  on public.members for delete
  using (user_id = auth.uid());

create policy "members can read events"
  on public.events for select
  using (public.is_trip_member(trip_id));

create policy "members can add events as themselves"
  on public.events for insert
  with check (
    public.is_trip_member(trip_id)
    and member_id in (select public.my_member_ids())
  );

create policy "authors can edit their events"
  on public.events for update
  using (member_id in (select public.my_member_ids()));

create policy "authors can delete their events"
  on public.events for delete
  using (member_id in (select public.my_member_ids()));

create policy "members can read messages"
  on public.messages for select
  using (public.is_trip_member(trip_id));

create policy "members can send messages as themselves"
  on public.messages for insert
  with check (
    public.is_trip_member(trip_id)
    and member_id in (select public.my_member_ids())
  );

create policy "members can see family locations"
  on public.locations for select
  using (public.is_trip_member(trip_id));

create policy "members can share their own location"
  on public.locations for insert
  with check (
    public.is_trip_member(trip_id)
    and member_id in (select public.my_member_ids())
  );

create policy "members can move their own pin"
  on public.locations for update
  using (member_id in (select public.my_member_ids()));

create policy "members can stop sharing"
  on public.locations for delete
  using (member_id in (select public.my_member_ids()));

create policy "members can read travel info"
  on public.logistics for select
  using (public.is_trip_member(trip_id));

create policy "members can add travel info as themselves"
  on public.logistics for insert
  with check (
    public.is_trip_member(trip_id)
    and member_id in (select public.my_member_ids())
  );

create policy "members can delete travel info"
  on public.logistics for delete
  using (public.is_trip_member(trip_id));
