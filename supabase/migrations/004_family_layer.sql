-- Kinvoy — the persistent family layer.
-- A family group lives ABOVE trips: standing chat, shared calendar, and
-- always-on (opt-in) location sharing with no date window. Trips keep their
-- own scoped chat/map/calendar and their trip-dates-only location rule.
-- Run after 003_expenses_polls_kinds.sql.

create table public.families (
  id          uuid primary key default gen_random_uuid(),
  name        text not null,
  invite_code text not null unique,
  created_by  uuid not null references auth.users (id),
  created_at  timestamptz not null default now()
);

create table public.family_members (
  id           uuid primary key default gen_random_uuid(),
  family_id    uuid not null references public.families (id) on delete cascade,
  user_id      uuid not null references auth.users (id),
  display_name text not null,
  joined_at    timestamptz not null default now(),
  unique (family_id, user_id)
);

create table public.family_messages (
  id         uuid primary key default gen_random_uuid(),
  family_id  uuid not null references public.families (id) on delete cascade,
  member_id  uuid not null references public.family_members (id) on delete cascade,
  content    text not null check (char_length(content) <= 4000),
  created_at timestamptz not null default now()
);

create table public.family_events (
  id            uuid primary key default gen_random_uuid(),
  family_id     uuid not null references public.families (id) on delete cascade,
  member_id     uuid not null references public.family_members (id) on delete cascade,
  title         text not null,
  notes         text,
  location_name text,
  starts_at     timestamptz not null,
  ends_at       timestamptz,
  created_at    timestamptz not null default now()
);

-- Always-on opt-in location: one row per family member, no date window.
-- Turning sharing off deletes the row.
create table public.family_locations (
  member_id  uuid primary key references public.family_members (id) on delete cascade,
  family_id  uuid not null references public.families (id) on delete cascade,
  latitude   double precision not null,
  longitude  double precision not null,
  updated_at timestamptz not null default now()
);

create index on public.family_members (family_id);
create index on public.family_messages (family_id, created_at);
create index on public.family_events (family_id, starts_at);
create index on public.family_locations (family_id);

-- ------------------------------------------------------------- helpers

create or replace function public.is_family_member(f uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1 from public.family_members
    where family_id = f and user_id = auth.uid()
  );
$$;

create or replace function public.my_family_member_ids()
returns setof uuid
language sql
security definer
set search_path = public
stable
as $$
  select id from public.family_members where user_id = auth.uid();
$$;

-- ------------------------------------------------------ create / join

create or replace function public.create_family(
  p_name text,
  p_display_name text
)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_code text;
  v_family families;
  v_member family_members;
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;

  loop
    v_code := (
      select string_agg(substr('ABCDEFGHJKLMNPQRSTUVWXYZ23456789', (floor(random() * 32) + 1)::int, 1), '')
      from generate_series(1, 6)
    );
    exit when not exists (select 1 from families where invite_code = v_code)
      and not exists (select 1 from trips where invite_code = v_code);
  end loop;

  insert into families (name, invite_code, created_by)
  values (trim(p_name), v_code, auth.uid())
  returning * into v_family;

  insert into family_members (family_id, user_id, display_name)
  values (v_family.id, auth.uid(), trim(p_display_name))
  returning * into v_member;

  return json_build_object('family', row_to_json(v_family), 'member', row_to_json(v_member));
end;
$$;

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

  return json_build_object('family', row_to_json(v_family), 'member', row_to_json(v_member));
end;
$$;

-- ----------------------------------------------------------------- RLS

alter table public.families enable row level security;
alter table public.family_members enable row level security;
alter table public.family_messages enable row level security;
alter table public.family_events enable row level security;
alter table public.family_locations enable row level security;

create policy "family members can read their family"
  on public.families for select
  using (public.is_family_member(id));

create policy "family members can read the roster"
  on public.family_members for select
  using (public.is_family_member(family_id));

create policy "family members can leave"
  on public.family_members for delete
  using (user_id = auth.uid());

create policy "family members can read messages"
  on public.family_messages for select
  using (public.is_family_member(family_id));

create policy "family members can send messages as themselves"
  on public.family_messages for insert
  with check (
    public.is_family_member(family_id)
    and member_id in (select public.my_family_member_ids())
  );

create policy "family members can read events"
  on public.family_events for select
  using (public.is_family_member(family_id));

create policy "family members can add events as themselves"
  on public.family_events for insert
  with check (
    public.is_family_member(family_id)
    and member_id in (select public.my_family_member_ids())
  );

create policy "authors can update their family events"
  on public.family_events for update
  using (member_id in (select public.my_family_member_ids()));

create policy "authors can delete their family events"
  on public.family_events for delete
  using (member_id in (select public.my_family_member_ids()));

create policy "family members can see family locations"
  on public.family_locations for select
  using (public.is_family_member(family_id));

create policy "family members can share their own location"
  on public.family_locations for insert
  with check (
    public.is_family_member(family_id)
    and member_id in (select public.my_family_member_ids())
  );

create policy "family members can move their own pin"
  on public.family_locations for update
  using (member_id in (select public.my_family_member_ids()));

create policy "family members can stop sharing"
  on public.family_locations for delete
  using (member_id in (select public.my_family_member_ids()));
