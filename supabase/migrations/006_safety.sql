-- Kinvoy — content reporting and user blocking.
-- Required by App Store Review Guideline 1.2 for apps with user-generated
-- content: users must be able to report objectionable content and block
-- abusive users. Run after 005_family_trips.sql.

-- ---------------------------------------------------------------- reports

create table public.reports (
  id           uuid primary key default gen_random_uuid(),
  reporter_id  uuid not null references auth.users (id),
  content_kind text not null check (content_kind in ('trip_message', 'family_message', 'poll', 'photo', 'event', 'member')),
  content_id   uuid not null,
  reason       text not null check (char_length(reason) <= 500),
  created_at   timestamptz not null default now()
);

create index on public.reports (created_at desc);

alter table public.reports enable row level security;

-- Anyone signed in can file a report; nobody can read them back from the
-- client (they're reviewed in the Supabase dashboard).
create policy "signed-in users can report"
  on public.reports for insert
  with check (auth.uid() = reporter_id);

-- ----------------------------------------------------------------- blocks

-- Blocking is per-user and symmetric in effect: blocked people's messages,
-- photos, and polls are hidden from the blocker everywhere in the app.
create table public.blocks (
  blocker_id uuid not null references auth.users (id),
  blocked_id uuid not null references auth.users (id),
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id),
  check (blocker_id <> blocked_id)
);

alter table public.blocks enable row level security;

create policy "users see their own blocks"
  on public.blocks for select
  using (blocker_id = auth.uid());

create policy "users can block"
  on public.blocks for insert
  with check (blocker_id = auth.uid());

create policy "users can unblock"
  on public.blocks for delete
  using (blocker_id = auth.uid());

-- Resolve a trip/family member id to the underlying user, so the client can
-- block by member without exposing the whole roster's user ids.
create or replace function public.user_id_for_member(p_member_id uuid, p_scope text)
returns uuid
language plpgsql
security definer
set search_path = public
stable
as $$
declare
  v_user uuid;
begin
  if p_scope = 'family' then
    select user_id into v_user from family_members
    where id = p_member_id and public.is_family_member(family_id);
  else
    select user_id into v_user from members
    where id = p_member_id and public.is_trip_member(trip_id);
  end if;
  return v_user;
end;
$$;

-- --------------------------------------------------------- delete my data

-- In-app account deletion (App Store Guideline 5.1.1(v)). Removes every
-- membership and everything owned by the caller, then the auth user itself.
create or replace function public.delete_my_account()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user uuid := auth.uid();
begin
  if v_user is null then
    raise exception 'not authenticated';
  end if;

  -- Content authored by this user's memberships cascades from the member
  -- rows; delete memberships first, then any families/trips left empty.
  delete from members where user_id = v_user;
  delete from family_members where user_id = v_user;
  delete from blocks where blocker_id = v_user or blocked_id = v_user;

  delete from trips t
  where t.created_by = v_user
    and not exists (select 1 from members m where m.trip_id = t.id);

  delete from families f
  where f.created_by = v_user
    and not exists (select 1 from family_members fm where fm.family_id = f.id);

  delete from auth.users where id = v_user;
end;
$$;
