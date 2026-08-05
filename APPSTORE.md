# App Store listing — Kinvoy

Everything App Store Connect asks for, drafted. Copy/paste each field.
Character limits noted; all drafts are within them.

---

## App Information

**Name** (30 max)

```
Kinvoy
```

**Subtitle** (30 max)

```
Family trips, chat & map
```

**Primary category:** Travel
**Secondary category:** Lifestyle

**Support URL**

```
https://kendallcoding202.github.io/kinvoy/
```

**Privacy Policy URL**

```
https://kendallcoding202.github.io/kinvoy/privacy.html
```

**Marketing URL** (optional) — same as Support URL.

---

## Keywords (100 characters max, comma separated, no spaces)

```
family,trip,vacation,group,travel,planner,itinerary,shared,calendar,chat,location,packing,expenses
```

*(97 characters. Don't repeat words already in the name or subtitle — Apple
indexes those separately.)*

---

## Promotional Text (170 max — editable any time without review)

```
Planning a trip with family or friends? Keep the group chat, the calendar, everyone's location, photos, and who-paid-what in one place instead of five apps.
```

---

## Description (4000 max)

```
Kinvoy keeps your people organized — every day at home, and every mile of the trip.

Group texts scroll away. Screenshots of confirmations get lost. Someone always asks "wait, what time are we leaving?" Kinvoy puts the whole group in one place: a standing chat, a shared calendar, an opt-in map, and a dedicated workspace for every trip you take together.

YOUR GROUP, EVERY DAY
• One standing chat for the whole group — no more scrolling back through a text thread
• A shared calendar for games, birthdays, dinners, and school events
• An opt-in map so you can see where everyone is, without asking
• Belong to more than one group: your family, the in-laws, a friend group. Switch with one tap.

A WORKSPACE FOR EVERY TRIP
Open a trip and everything about it is right there:
• Day-by-day plans everyone can add to
• A trip-only chat that stays separate from everyday conversation
• A trip map with location sharing that works only during the trip dates and switches itself off when the trip ends
• Flights, lodging, rental cars, and tickets where the whole group can find them
• Weather for your destination and your exact dates
• Packing and grocery lists you can assign to people
• A shared photo album
• Expenses with an automatic even split, so you know who owes who
• Polls for the "beach or pool?" decisions

IDEAS WHEN NOBODY CAN DECIDE
Ask for suggestions and get specific, real things to do at your destination — filtered for outdoors, food, rainy days, free, or with little kids.

BUILT FOR REAL FAMILIES
• No accounts and no passwords. Share a six-character code; people type their name and they're in. Easy enough for grandparents.
• Location sharing is always opt-in. Turn it off and your location is deleted, not hidden.
• Trips shared with your group add everyone automatically. Keep one private and it's invite-code only.
• Works on iPhone, iPad, and Apple Silicon Macs — plan on the big screen, use it on the road.

Vacations, camping trips, birthdays, holidays, reunions, sports weekends — every occasion gets its own workspace, and your group stays in one place between them.
```

---

## What's New in This Version (first release)

```
The first release of Kinvoy. Group chat, a shared calendar, opt-in location, and a full workspace for every trip — plans, photos, expenses, packing lists, weather, and AI suggestions for what to do.
```

---

## App Privacy questionnaire

Answer **Yes** to "Do you or your third-party partners collect data from this app?"

For every type below: used for **App Functionality** only, **linked to the user**,
and **not used for tracking**.

| Data type | Collected? | Notes |
|---|---|---|
| Coarse/Precise Location | **Yes** | Only when the user turns sharing on |
| User Content — Photos or Videos | **Yes** | Trip album uploads |
| User Content — Customer Support | No | |
| User Content — Other (messages, plans, lists, expenses) | **Yes** | |
| Identifiers — User ID | **Yes** | Anonymous account id |
| Contact Info — Name | **Yes** | Self-chosen display name |
| Contact Info — Email, Phone | No | Never requested |
| Contacts | No | |
| Usage Data | No | |
| Diagnostics | No | |
| Purchases, Financial Info | No | Expense amounts are user-entered content, not payment data |
| Browsing History, Search History | No | |
| Health & Fitness, Sensitive Info | No | |

**Tracking:** No. Kinvoy does not track users across apps or websites.

---

## Age Rating questionnaire

- Cartoon/Fantasy Violence, Realistic Violence, Sexual Content, Nudity,
  Profanity, Alcohol/Tobacco/Drugs, Horror, Gambling, Contests: **None**
- **Unrestricted Web Access: No**
- **User-Generated Content: Yes** — this is the important one. Kinvoy has
  in-app reporting, blocking, a terms agreement with a zero-tolerance policy,
  and published contact info.

Expected rating: **12+** (apps with user-generated content generally land here).

---

## App Review Information

**Sign-in required:** No — the app creates an anonymous account automatically.

**Notes for the reviewer** (paste into the Notes field):

```
Kinvoy needs no login. On first launch you'll agree to the terms, then either create a group or join one.

TO REVIEW QUICKLY
1. Tap "Set up your family", name it anything, enter any display name.
2. You'll land on Home. The chip at the top names your group.
3. Chat, Calendar, and Map are the group's everyday tools.
4. The Trips tab creates a trip; tap it to open its full-screen workspace (plans, chat, map, ideas, info).

USER-GENERATED CONTENT (Guideline 1.2)
- Press and hold any message, poll, or photo to report it, with an option to block the author in the same sheet. Blocked people's content is hidden everywhere.
- Terms with an explicit zero-tolerance policy must be accepted before use, and are linked at https://kendallcoding202.github.io/kinvoy/terms.html
- Reports reach us for review within 24 hours; contact is published on the support site.

LOCATION (Guideline 5.1.1)
- Location is never required. Both toggles default to off.
- Trip sharing is only permitted between the trip's start and end dates and stops automatically afterward.
- Turning either toggle off deletes the stored location rather than hiding it.

ACCOUNT DELETION (Guideline 5.1.1(v))
- Home > group card > Delete my account. Permanently removes the account and all content.

The activity suggestions in a trip's Ideas tab are generated by the Anthropic API from the destination and dates only; no user content is sent.
```

---

## Screenshots

Captured from the simulator with `-screenshotMode` (demo data, so no real
accounts appear).

Required sizes, both produced at native resolution:
- **iPhone 6.9"** — 1320 × 2868 (iPhone 17 Pro Max)
- **iPad 13"** — 2064 × 2752 (iPad Pro 13-inch)

Suggested order and captions:

1. **Home** — "Your whole group, in one place"
2. **Trip plans** — "A day-by-day plan everyone can add to"
3. **Group chat** — "One thread that doesn't scroll away"
4. **Trip map** — "See everyone — only during the trip"
5. **Ideas** — "Out of ideas? Get real suggestions"
6. **Trips list** — "Every trip gets its own workspace"

To regenerate:

```bash
xcrun simctl launch <device-udid> com.kendallsorenson.getaway -screenshotMode
xcrun simctl io <device-udid> screenshot shot.png
```

---

## Premium subscription (built, dormant)

The plumbing ships in v1 but `SubscriptionService.paywallEnabled` is `false`,
so everything is free and no paywall appears. Flip that one constant to turn
Premium on in a later release.

**Model:** entitlement belongs to the **group**, not the buyer. One member
subscribes; everyone in that group gets Premium.

**Free tier:** one group, one active trip, chat, calendar, map — forever.
Location sharing is never gated.
**Premium:** unlimited trips and groups, unlimited AI ideas, photo albums,
expenses.

**Products to create** (App Store Connect → Subscriptions → new group
"Kinvoy Premium"):

| Product ID | Duration | Price | Intro offer |
|---|---|---|---|
| `com.kendallsorenson.getaway.premium.monthly` | 1 month | $4.99 | 7-day free trial |
| `com.kendallsorenson.getaway.premium.yearly` | 1 year | $29.99 | 7-day free trial |

**Before flipping the switch:**

1. Sign the **Paid Applications Agreement** (Business tab) with banking + tax —
   takes days to clear, nothing works until it does.
2. Create the two products above with those exact IDs.
3. Run migration `008_subscriptions.sql`.
4. Deploy the Edge Function: `supabase functions deploy verify-subscription`.
5. Test in the simulator using `App/Resources/Kinvoy.storekit` (Scheme →
   Options → StoreKit Configuration), then with a Sandbox tester on device.
6. Set `paywallEnabled = true`, submit the update.
7. Grandfather early users: insert a far-future row in `subscriptions` for
   their group so founding families keep Premium free.

**Extra listing fields once Premium is live:** the App Store page will require
the subscription's name, duration, price, and links to the Terms of Use and
Privacy Policy in the metadata as well as in the app.

**Hardening for later:** the Edge Function checks the transaction's claims
(bundle id, product id, expiry) but doesn't yet validate Apple's certificate
chain. Add App Store Server Notifications V2 so cancellations, refunds, and
billing failures revoke access automatically instead of waiting for expiry.

---

## Pre-submission checklist

- [x] App icon (1024, no alpha)
- [x] Privacy policy and support pages live
- [x] Terms acceptance with zero-tolerance policy in-app
- [x] Report + block for user-generated content
- [x] In-app account deletion
- [x] Encryption declaration (`ITSAppUsesNonExemptEncryption: false`)
- [ ] Screenshots uploaded (iPhone 6.9" + iPad 13")
- [ ] Description, keywords, subtitle entered
- [ ] App Privacy questionnaire submitted
- [ ] Age rating completed
- [ ] Build attached to the version
- [ ] Submit for review
