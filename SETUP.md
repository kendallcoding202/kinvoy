# Getaway — Backend Setup

The app runs in **demo mode** out of the box (sample data, no network). To make
it real — shared trips, chat, locations, AI ideas — set up the free Supabase
backend. ~15 minutes, one time.

## 1. Create the Supabase project

1. Go to [supabase.com](https://supabase.com) → sign in → **New project**.
2. Name it `getaway` (any region close to you). This is a NEW project — do not
   reuse a project from another app.
3. Wait for it to finish provisioning.

## 2. Enable anonymous sign-ins

Dashboard → **Authentication → Sign In / Up** → turn ON **Allow anonymous
sign-ins** → Save.

(This is what makes "enter an invite code + your name" work with no passwords.
Later, anonymous users can be upgraded to email accounts for subscriptions.)

## 3. Create the database

Dashboard → **SQL Editor** → New query → paste the entire contents of
[`supabase/migrations/001_init.sql`](supabase/migrations/001_init.sql) → **Run**.

You should see "Success. No rows returned."

## 4. Deploy the AI suggestions function

Requires the [Supabase CLI](https://supabase.com/docs/guides/cli) (`brew install supabase/tap/supabase`):

```bash
supabase login
supabase link --project-ref YOUR_PROJECT_REF   # ref is in the dashboard URL
supabase secrets set ANTHROPIC_API_KEY=sk-ant-YOUR-KEY
supabase functions deploy suggest-activities
```

Get an Anthropic API key at [console.anthropic.com](https://console.anthropic.com).
Suggestions cost roughly a cent per request.

## 5. Point the app at your project

Dashboard → **Project Settings → API**. Copy:

- **Project URL** (like `https://abcdefgh.supabase.co`)
- **anon public** key

Paste both into [`App/Config/AppConfig.swift`](App/Config/AppConfig.swift)
replacing the `EDIT_ME` values. Rebuild the app. Done — the demo button
disappears and Create/Join work for real.

## 6. (When ready for the App Store)

- Rename the app: change `name`, `PRODUCT_NAME`, `INFOPLIST_KEY_CFBundleDisplayName`,
  and `PRODUCT_BUNDLE_IDENTIFIER` in `project.yml`, then run `xcodegen generate`.
- Add a real 1024×1024 icon at
  `App/Resources/Assets.xcassets/AppIcon.appiconset/`.
- Archive in Xcode with your team (already set: 4985QRD6MB) and upload to
  TestFlight for the family.
