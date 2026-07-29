-- Famlio — event workspace kinds, expenses with splitting, polls in chat.
-- Run this in the Supabase SQL editor after 002_checklists_photos.sql.

-- --------------------------------------------------- workspace kinds

alter table public.trips
  add column kind text not null default 'vacation'
  check (kind in ('vacation', 'camping', 'birthday', 'holiday', 'reunion', 'sports', 'getaway', 'other'));

-- create_trip gains a kind parameter (old 5-arg version is replaced).
drop function if exists public.create_trip(text, text, date, date, text);

create or replace function public.create_trip(
  p_name text,
  p_destination text,
  p_starts_on date,
  p_ends_on date,
  p_display_name text,
  p_kind text default 'vacation'
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

  loop
    v_code := (
      select string_agg(substr('ABCDEFGHJKLMNPQRSTUVWXYZ23456789', (floor(random() * 32) + 1)::int, 1), '')
      from generate_series(1, 6)
    );
    exit when not exists (select 1 from trips where invite_code = v_code);
  end loop;

  insert into trips (name, destination, starts_on, ends_on, invite_code, created_by, kind)
  values (trim(p_name), trim(p_destination), p_starts_on, p_ends_on, v_code, auth.uid(), coalesce(p_kind, 'vacation'))
  returning * into v_trip;

  insert into members (trip_id, user_id, display_name)
  values (v_trip.id, auth.uid(), trim(p_display_name))
  returning * into v_member;

  return json_build_object('trip', row_to_json(v_trip), 'member', row_to_json(v_member));
end;
$$;

-- --------------------------------------------------------- expenses

create table public.expenses (
  id           uuid primary key default gen_random_uuid(),
  trip_id      uuid not null references public.trips (id) on delete cascade,
  member_id    uuid not null references public.members (id) on delete cascade,  -- who paid
  title        text not null,
  amount_cents bigint not null check (amount_cents > 0),
  created_at   timestamptz not null default now()
);

create index on public.expenses (trip_id, created_at desc);

alter table public.expenses enable row level security;

create policy "members can see expenses"
  on public.expenses for select
  using (public.is_trip_member(trip_id));

create policy "members can add expenses they paid"
  on public.expenses for insert
  with check (
    public.is_trip_member(trip_id)
    and member_id in (select public.my_member_ids())
  );

create policy "payers can delete their expenses"
  on public.expenses for delete
  using (member_id in (select public.my_member_ids()));

-- ------------------------------------------------------------ polls

create table public.polls (
  id         uuid primary key default gen_random_uuid(),
  trip_id    uuid not null references public.trips (id) on delete cascade,
  member_id  uuid not null references public.members (id) on delete cascade,
  question   text not null,
  options    text[] not null check (array_length(options, 1) between 2 and 6),
  created_at timestamptz not null default now()
);

create table public.poll_votes (
  poll_id      uuid not null references public.polls (id) on delete cascade,
  trip_id      uuid not null references public.trips (id) on delete cascade,
  member_id    uuid not null references public.members (id) on delete cascade,
  option_index int not null check (option_index >= 0),
  created_at   timestamptz not null default now(),
  primary key (poll_id, member_id)
);

create index on public.polls (trip_id, created_at);
create index on public.poll_votes (trip_id);

alter table public.polls enable row level security;
alter table public.poll_votes enable row level security;

create policy "members can see polls"
  on public.polls for select
  using (public.is_trip_member(trip_id));

create policy "members can create polls as themselves"
  on public.polls for insert
  with check (
    public.is_trip_member(trip_id)
    and member_id in (select public.my_member_ids())
  );

create policy "authors can delete their polls"
  on public.polls for delete
  using (member_id in (select public.my_member_ids()));

create policy "members can see votes"
  on public.poll_votes for select
  using (public.is_trip_member(trip_id));

create policy "members can vote as themselves"
  on public.poll_votes for insert
  with check (
    public.is_trip_member(trip_id)
    and member_id in (select public.my_member_ids())
  );

create policy "members can change their vote"
  on public.poll_votes for update
  using (member_id in (select public.my_member_ids()));

create policy "members can retract their vote"
  on public.poll_votes for delete
  using (member_id in (select public.my_member_ids()));
