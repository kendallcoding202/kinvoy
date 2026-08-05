-- Kinvoy — let account deletion succeed for people who filed reports.
--
-- reports.reporter_id pointed at auth.users with the default RESTRICT, so
-- delete_my_account() failed with a foreign-key violation for anyone who had
-- ever reported something. Reports are moderation history and shouldn't
-- vanish, so the author is anonymized instead of the row being deleted.

alter table public.reports
  alter column reporter_id drop not null;

alter table public.reports
  drop constraint if exists reports_reporter_id_fkey;

alter table public.reports
  add constraint reports_reporter_id_fkey
  foreign key (reporter_id) references auth.users (id) on delete set null;
