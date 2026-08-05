-- Comp Premium to a group (founding families, friend groups, support cases).
--
-- Entitlement is group-level, so this unlocks Premium for everyone in the
-- group at once. No Apple involvement and no money changes hands, so this is
-- not an alternative purchase mechanism — you're simply not charging them.
--
-- Run in the Supabase SQL editor.

-- 1. Find the group's id by its invite code (or name).
select id, name, invite_code
from families
where invite_code = 'X9NFAS';        -- <-- change me

-- 2. Grant Premium until 2099. Re-running just extends the same row.
insert into subscriptions (
  family_id, product_id, original_transaction_id, expires_at, environment
)
values (
  'PASTE-THE-FAMILY-ID-HERE'::uuid,  -- <-- from step 1
  'comp',
  'comp-' || gen_random_uuid()::text,
  '2099-01-01T00:00:00Z',
  'Comp'
)
on conflict (family_id) do update
  set expires_at = excluded.expires_at,
      product_id = excluded.product_id,
      environment = excluded.environment,
      updated_at = now();

-- 3. Confirm.
select f.name, s.product_id, s.expires_at
from subscriptions s
join families f on f.id = s.family_id
where s.expires_at > now();

-- To revoke:
-- delete from subscriptions where family_id = 'PASTE-THE-FAMILY-ID-HERE'::uuid;

-- To comp every group that exists today (e.g. grandfather all early users
-- on the day you switch the paywall on):
-- insert into subscriptions (family_id, product_id, original_transaction_id, expires_at, environment)
-- select id, 'comp', 'comp-' || gen_random_uuid()::text, '2099-01-01T00:00:00Z', 'Comp'
-- from families
-- on conflict (family_id) do nothing;
