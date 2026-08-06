# Roadmap — from vacation app to Family Hub

The long-term vision: the **"Operating System for Family Life"** — an app
families open every day to plan, communicate, organize, share memories,
preserve family history, and get AI help. Not just families with kids:
couples, grandparents, blended families, friend groups, sports teams,
reunion and travel groups.

Why it can win: it solves the real problem of juggling five different apps
(calendar + group text + location + lists + photos), it has daily-use surface
area (schedule, locations, messages, grocery lists, reminders), and the
**Family Timeline** gives it long-term emotional lock-in — an automatic
private family history with photos, milestones, AI-written trip summaries,
"On This Day" memories, and monthly/yearly recap stories.

This file captures that vision in phases so each version ships fast and
nothing gets lost.

**Architecture note:** in the schema, a *trip* is really an **event
workspace** — dates + members + chat + calendar + map + info. Growing into the
Family Hub means adding workspace types (camping trip, reunion, holiday,
sports season) and a persistent *family* layer above workspaces. It is an
extension of the current schema, not a rewrite. Anonymous users are already
upgradeable to real accounts (Supabase identity linking) when subscriptions
arrive.

## Phase 1 — Vacation v1 (built)

- Trip workspaces with invite codes, no-password join
- Shared plans calendar, group chat, trip-dates-only location sharing
- Travel info (flights, lodging, rental car, tickets), weather forecast
- AI activity/restaurant suggestions (Claude via Edge Function)

## 1.1 — Account recovery (do this first)

**The problem.** Every device gets an anonymous Supabase user
([SupabaseService.swift:21](App/Services/SupabaseService.swift:21)), and every
row keys off `auth.uid()`. Lose the device, reinstall, or delete the app and
that identity is gone — along with the membership rows that connect the person
to their group and its history.

This was an acceptable trade while everything was free. It stops being
acceptable now that Premium is live. Restore Purchases recovers the *Apple*
side fine, and `verify-subscription` will grant Premium to whatever group the
user is in — but if they can't get back into their group, that's cold comfort.
A family can re-invite each other; someone whose group is just themselves has
no path back, and they're the person who just paid $29.99.

**The approach.** Supabase identity linking keeps the *same* `auth.users.id`
when an anonymous user links a real identity. So there is no data migration and
no re-keying: `members`, `family_members`, `subscriptions.purchased_by`, and
every RLS policy built on `auth.uid()` keep working untouched. That is what
makes this a small change rather than a rewrite.

**Sign in with Apple**, specifically: one tap on iOS, no password to forget, no
email round-trip. Apple also requires it if we ever add Google or Facebook
login, so starting here avoids doing the work twice.

**Keep it optional.** The no-password join is a real advantage over Cozi and
the other family apps — do not put a signup wall in front of it. Offer linking
as "secure your account" rather than a gate.

Steps:

1. Add the Sign in with Apple capability and entitlement.
2. `linkIdentity(provider: .apple)` on the existing anonymous session; on a
   fresh install, `signInWithIdToken` returns the *same* user, restoring
   membership automatically.
3. Prompt where the stakes are visible, not on launch: after a successful
   purchase, and as a dismissible row on the group screen. Never blocking.
4. Show linked state on the group screen so people can tell they're covered.
5. Make sure account deletion still removes the linked identity — the 5.1.1(v)
   flow must not leave an orphaned Apple identity behind.

Edge cases worth testing:

- Two anonymous users linking the *same* Apple ID — Supabase rejects the second
  link. Decide whether to merge or to sign into the existing account and
  abandon the anonymous one (probably the latter; simpler and less lossy than
  a merge).
- Linking while a subscription is active: confirm the entitlement still resolves
  after linking, since `purchased_by` points at the same id.
- A user who links, deletes the app, reinstalls, signs in, and expects both
  their group *and* Premium back. This is the whole point of the feature — it
  is the test that matters.

## Phase 2 — Better vacations

- **Photos**: shared trip album (Supabase Storage buckets per trip)
- **Expenses**: shared purchases, bill splitting, who-owes-who summary
- **Packing / checklists**: shared lists with assignments and check-off
- **Polls in chat**: "Beach or pool tomorrow?" (new `polls` table + message type)
- **Push notifications**: new messages/plans (APNs; requires paid dev account —
  already have team 4985QRD6MB)
- **AI trip assistant**: chat with an AI that knows the itinerary, weather, and
  travel info ("what should we do Thursday morning before the 1pm checkout?")
- Realtime (Supabase channels) instead of polling for chat/locations

## Phase 3 — Event workspaces for everything

- Workspace types: vacations, camping, reunions, holidays, birthdays, sports
  tournaments, school events, weekend getaways
- Each includes the same kit: chat, calendar, map, itinerary, checklists,
  expenses, photos, notes, AI assistant
- **Home dashboard**: today's schedule, upcoming events, family locations,
  recent messages, weather, AI suggestions, shortcuts

## Phase 4 — The family layer (daily use)

- Persistent **family group** above workspaces; kids/parents roles
- Chat organized by: whole family, per-event, custom groups, DMs; voice
  messages, shared reminders, lists
- **Family location**: always-on opt-in sharing, battery status, ETA
  ("leaving now"), arrival/departure notifications, safe-zone alerts (home,
  school, grandparents), emergency sharing
- **Shared organization**: family calendar + individual calendars, color
  coding, calendar sync (EventKit); chores, grocery/to-do lists, task
  assignment, due dates, recurring reminders
- **Budgeting**: vacation budgets, event expenses, spending summaries
- **Smart notifications**: "leave now to arrive on time", "packing list 80%
  done", "rain expected during your camping trip", "Grandma's birthday next
  week"

## Phase 5 — Memories & differentiation

- **Family Timeline (signature feature)**: auto-built private family
  history — trips, birthdays, holidays, milestones, sports and school
  memories, journal entries, "On This Day" memories, AI-written trip
  summaries, monthly and yearly recap stories
- Memory search ("show me all our beach trips")
- AI vacation recap videos, automatic memory books (printable yearly
  family books)
- **Family AI, full version**: understands each member (ages, preferences,
  budgets), resolves scheduling conflicts, generates itineraries, shopping
  lists, and packing lists on request
- Smart notifications: time-to-leave, arrival, weather alerts, packing
  reminders, birthday reminders, event countdowns, traffic alerts
- Smart home hooks (arrival automations, shared shopping lists)

## Monetization sketch

- **Free**: one family, basic calendar, chat, shared events, limited AI,
  basic timeline
- **Premium (subscription)**: unlimited events, advanced AI planning, smart
  reminders, unlimited Family Timeline, expense tracking, shared cloud
  storage, automatic memory books, AI-generated recap videos
- Requires: email accounts (link anonymous → email), StoreKit 2 +
  server-side receipt checks, feature gating in RLS/Edge Functions
