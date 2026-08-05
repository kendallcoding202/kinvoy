-- Kinvoy — Premium entitlement.
--
-- Entitlement belongs to the GROUP, not the buyer. One person subscribes and
-- everyone in the family gets Premium; otherwise adoption dies the moment
-- Grandma is asked to pay to see the trip calendar.

create table public.subscriptions (
  family_id               uuid primary key references public.families (id) on delete cascade,
  purchased_by            uuid references auth.users (id) on delete set null,
  product_id              text not null,
  original_transaction_id text not null,
  expires_at              timestamptz not null,
  is_trial                boolean not null default false,
  environment             text not null default 'Production',
  updated_at              timestamptz not null default now()
);

create index on public.subscriptions (original_transaction_id);
create index on public.subscriptions (expires_at);

alter table public.subscriptions enable row level security;

-- Members can see their group's status (to render the paywall or not).
create policy "members can read their group's subscription"
  on public.subscriptions for select
  using (public.is_family_member(family_id));

-- Writes only ever happen through the verify-subscription Edge Function,
-- which uses the service role. No client-side insert/update policy exists
-- on purpose — a client can't grant itself Premium.

-- ------------------------------------------------------------- entitlement

create or replace function public.family_has_premium(f uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1 from public.subscriptions
    where family_id = f and expires_at > now()
  );
$$;

-- Convenience for the client: premium status for every group I belong to.
create or replace function public.my_premium_families()
returns setof uuid
language sql
security definer
set search_path = public
stable
as $$
  select s.family_id
  from public.subscriptions s
  where s.expires_at > now()
    and public.is_family_member(s.family_id);
$$;
