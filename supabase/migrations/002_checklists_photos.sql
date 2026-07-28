-- Getaway — checklists (packing/grocery/todo) and shared photo album.
-- Run this in the Supabase SQL editor after 001_init.sql.

-- ------------------------------------------------------------ checklists

create table public.checklists (
  id         uuid primary key default gen_random_uuid(),
  trip_id    uuid not null references public.trips (id) on delete cascade,
  member_id  uuid not null references public.members (id) on delete cascade,
  title      text not null,
  created_at timestamptz not null default now()
);

create table public.checklist_items (
  id                 uuid primary key default gen_random_uuid(),
  checklist_id       uuid not null references public.checklists (id) on delete cascade,
  trip_id            uuid not null references public.trips (id) on delete cascade,
  title              text not null,
  assigned_member_id uuid references public.members (id) on delete set null,
  is_done            boolean not null default false,
  created_at         timestamptz not null default now()
);

create index on public.checklists (trip_id);
create index on public.checklist_items (checklist_id);
create index on public.checklist_items (trip_id);

alter table public.checklists enable row level security;
alter table public.checklist_items enable row level security;

create policy "members can read checklists"
  on public.checklists for select
  using (public.is_trip_member(trip_id));

create policy "members can create checklists as themselves"
  on public.checklists for insert
  with check (
    public.is_trip_member(trip_id)
    and member_id in (select public.my_member_ids())
  );

create policy "members can delete checklists"
  on public.checklists for delete
  using (public.is_trip_member(trip_id));

create policy "members can read items"
  on public.checklist_items for select
  using (public.is_trip_member(trip_id));

create policy "members can add items"
  on public.checklist_items for insert
  with check (public.is_trip_member(trip_id));

-- Anyone on the trip can check off or assign items (it's collaborative).
create policy "members can update items"
  on public.checklist_items for update
  using (public.is_trip_member(trip_id));

create policy "members can delete items"
  on public.checklist_items for delete
  using (public.is_trip_member(trip_id));

-- ----------------------------------------------------------- photo album

create table public.photos (
  id           uuid primary key default gen_random_uuid(),
  trip_id      uuid not null references public.trips (id) on delete cascade,
  member_id    uuid not null references public.members (id) on delete cascade,
  storage_path text not null,
  created_at   timestamptz not null default now()
);

create index on public.photos (trip_id, created_at desc);

alter table public.photos enable row level security;

create policy "members can see trip photos"
  on public.photos for select
  using (public.is_trip_member(trip_id));

create policy "members can add photos as themselves"
  on public.photos for insert
  with check (
    public.is_trip_member(trip_id)
    and member_id in (select public.my_member_ids())
  );

create policy "authors can delete their photos"
  on public.photos for delete
  using (member_id in (select public.my_member_ids()));

-- Private storage bucket; files live at {trip_id}/{uuid}.jpg
insert into storage.buckets (id, name, public)
values ('trip-photos', 'trip-photos', false)
on conflict (id) do nothing;

create policy "members can view trip photo files"
  on storage.objects for select
  using (
    bucket_id = 'trip-photos'
    and public.is_trip_member(((storage.foldername(name))[1])::uuid)
  );

create policy "members can upload trip photo files"
  on storage.objects for insert
  with check (
    bucket_id = 'trip-photos'
    and public.is_trip_member(((storage.foldername(name))[1])::uuid)
  );

create policy "uploaders can delete their photo files"
  on storage.objects for delete
  using (bucket_id = 'trip-photos' and owner = auth.uid());
