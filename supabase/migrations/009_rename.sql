-- Kinvoy — let people fix a group or trip name after creating it.
--
-- Names were write-once, so a typo at setup was permanent. Any member can
-- rename; these are small trusted groups, and the alternative (only the
-- creator) strands a group whose creator has left.

create policy "members can rename their group"
  on public.families for update
  using (public.is_family_member(id))
  with check (public.is_family_member(id));

create policy "members can edit trip details"
  on public.trips for update
  using (public.is_trip_member(id))
  with check (public.is_trip_member(id));
