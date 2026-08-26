# App Store listing — Sproutly

Reference copy for the App Store Connect listing. **Not compiled into the app.**
`project.yml` sources only `- path: Sproutly`, so this directory sits outside the
target by construction and needs no exclusion rule.

## Age range — the claim that must stay true

**Sproutly covers 2 months to 5 years.**

The milestone catalog begins at the 2-month band and ends at 60 months. Every
place the range appears must say the same thing:

- the onboarding disclaimer step (`Views/OnboardingView.swift`)
- About the Data (`Views/AboutDataView.swift`)
- this file, and the App Store description

Do **not** describe Sproutly as covering "birth to 5", "0–5", or "newborns". A
parent who installs it for a two-week-old and finds nothing to track writes the
one-star review that says the app doesn't work — and they would be right.

For a baby under two months the app says so plainly and points to the
pediatrician and the newborn well-visits instead.

## Sources and attribution

Milestones are **paraphrased**, never quoted, from:

- **CDC, "Learn the Signs. Act Early."** (2022 revision) — a US federal work in
  the public domain.
- **World Health Organization, Motor Development Study** — used to cross-check
  gross motor so the set is not purely US-normed. WHO material is *not* public
  domain, so the same paraphrase discipline applies.
- **American Academy of Pediatrics** — well-visit screening ages only.

Sproutly is an independent educational tool. It is **not** affiliated with,
sponsored by, endorsed by, or reviewed by any of them, and no listing copy may
imply otherwise.

Two bands (15 and 30 months) contain a small number of items drawn from general
pediatric practice rather than CDC 2022 specifically, because the CDC entries for
those ages duplicate bands Sproutly already covers. See the comments above
`fifteenMonth` and `thirtyMonth` in `DataSeeder.swift`.

## Privacy

App Privacy must remain **Data Not Collected**. `Resources/PrivacyInfo.xcprivacy`
declares no tracking, no collected data types, and one accessed-API reason
(`CA92.1`, UserDefaults). Nothing in the app makes a network call.

Notifications are **local only** — no push, no remote, no entitlement, and no
usage-description string required.

## Category

**Lifestyle**, not Health & Fitness. Copy stays educational and never diagnoses.

## Pricing

One non-consumable unlock, family-shareable. **Never state a price in listing
copy or in the app** — pricing is per-territory and set in App Store Connect, and
every figure a parent sees comes from StoreKit's localised `displayPrice`.
