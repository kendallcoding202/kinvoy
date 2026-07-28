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
