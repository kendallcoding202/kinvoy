# Getaway 🌅

A family vacation app: one place for the trip's plans, chat, locations, travel
info, and ideas. Built with SwiftUI + Supabase.

## What it does (v1)

- **Trips with invite codes** — start a trip (name, destination, dates), share a
  6-character code; family joins with just the code and their name. No accounts,
  no passwords (anonymous Supabase auth under the hood).
- **Plans** — a shared trip calendar. Anyone can post events ("Dolphin cruise,
  Tuesday 10 AM"); everyone sees them, grouped by day.
- **Chat** — a group thread scoped to the trip, so vacation talk stays out of
  fourteen other text threads.
- **Family Map** — opt-in location sharing that *only works during the trip
  dates* and shuts off automatically when the trip ends. Sharing off = your pin
  is deleted, not hidden.
- **Ideas** — Claude-powered suggestions for the destination ("Rainy day",
  "Food", "With little kids"…), served from a Supabase Edge Function.
- **Trip info** — flight confirmations, lodging, rental car, tickets — plus a
  weather forecast for the trip dates (Open-Meteo, no key needed).
- **Demo mode** — full UI with sample data before the backend is configured.

## Project layout

```
project.yml                 XcodeGen spec — run `xcodegen generate` after changes
App/                        SwiftUI app (iOS 17+)
  Config/AppConfig.swift    EDIT ME: Supabase URL + anon key
  Models/                   Codable models mirroring the DB
  Services/                 Supabase client, trip state, location, weather, demo data
  Features/                 One folder per tab + onboarding
supabase/
  migrations/001_init.sql   Tables, invite-code RPCs, row-level security
  functions/                suggest-activities (Claude API, server-side)
SETUP.md                    Step-by-step backend setup
ROADMAP.md                  The bigger Family Hub vision, phased
```

## Build

```bash
brew install xcodegen   # once
xcodegen generate
open Getaway.xcodeproj  # then Run on a simulator or your phone
```

Backend setup: see [SETUP.md](SETUP.md).
