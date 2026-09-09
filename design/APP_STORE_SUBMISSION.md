# GetOut App Store submission handoff

This checklist covers the work that must be completed in Apple portals or on physical devices after the code is archived. Do not submit until every release gate is checked.

## URLs and contact

- Privacy policy: `https://parthdhroovji.me/GetOut`
- Terms and community rules: `https://parthdhroovji.me/GetOut/terms`
- Support, privacy, reporting, and deletion: `parthdhroovji1@gmail.com`
- Verify both URLs return HTTP 200 over HTTPS without a login after the portfolio repository is deployed.

## Suggested App Review notes

> GetOut is an iPhone-only social discovery app backed by Supabase. Users create an account with Sign in with Apple or Continue with Google before creating a public profile.
>
> Users publish spots directly. A publication confirmation explains that their profile and exact spot location become public. Users can report a spot or profile from its overflow menu, block a creator, unpublish their own spot, and delete their profile, content, and authentication record in Settings. Reports are reviewed daily at parthdhroovji1@gmail.com and in Supabase.
>
> Cannabis-related content is informational only and does not offer sales, ordering, or delivery. It is hidden unless the user privately confirms legal age and the device is in Canada or California. Publishing a cannabis-tagged spot also requires reverse-geocoded spot coordinates in Canada or California. Location denial and age decline keep this content hidden.

Provide App Review with a working Google test account, or explain that reviewers can use Sign in with Apple with their sandbox Apple ID. Do not provide a personal production account.

## App Privacy answers to verify in App Store Connect

Base the final answers on the shipping build and Apple's current definitions. Expected disclosures for this implementation are:

| Data type | Linked to user | Tracking | Purpose |
| --- | --- | --- | --- |
| User ID (opaque Supabase Auth UUID) | Yes | No | App functionality, account and abuse prevention |
| Name / username / profile bio | Yes | No | App functionality |
| Precise location of published spots | Yes | No | App functionality |
| User content (spot text, tags, reports) | Yes | No | App functionality, safety |
| Photos stored with private spot data | Yes | No | App functionality |
| Coarse/precise viewer location | Review final retention behavior | No | Nearby results and cannabis eligibility |

The app does not track users and does not use data for third-party advertising. Re-check the answers if analytics, crash reporting, ads, or another SDK is added. `PrivacyInfo.xcprivacy` declares the Supabase-backed data above, no tracking, and the UserDefaults required-reason API; App Store Connect privacy answers are still a separate manual task.

## Supabase release gate

- Apply every migration in `supabase/migrations` and confirm `supabase migration list` has no drift.
- Keep anonymous sign-ins disabled. Enable Apple and Google and verify public read plus authenticated/owner write RLS with two users.
- Confirm no secret/service-role key is embedded in the app.
- Confirm the App Store target includes only the capabilities actually used, including Sign in with Apple.
- Review `PublicReport` records every day.

## Physical-device and TestFlight matrix

- Account A and B: create distinct profiles and relaunch to recover the correct profile from each persisted Supabase session.
- Attempt the same normalized username from both accounts and verify the second creation is rejected.
- With a fresh install: verify Apple and Google login, account cancellation/error handling, and onboarding.
- Sign out and sign back in with each provider; verify the correct profile and private data are restored.
- Publish, page, block, report, unpublish, and delete data. Confirm Account B can no longer resolve Account A after deletion.
- Turn networking off during feed and write operations; verify cached content, error copy, and successful retry.
- Cannabis matrix: Canada, California, an ineligible jurisdiction, age declined, and location denied. Verify both feed visibility and publication.
- Confirm exact-location disclosure appears before every public publication.
- Confirm reports appear in Supabase and the support email is reachable.
- Run a full TestFlight pass using the Production schema before review.

## Listing and archive gate

- Use the generated 1024×1024 AppIcon and inspect the archived asset catalog for transparency, text, clipping, or missing slots.
- Capture current iPhone screenshots from the release build with no demo content or placeholder copy.
- Complete name, subtitle, description, keywords, support URL, privacy URL, copyright, category, and age-rating questionnaire.
- Answer the age-rating/cannabis-content questions accurately; do not describe GetOut as enabling cannabis purchases.
- Remove debug/demo records and confirm all visible buttons work in the submitted build.
- Archive with the Release configuration, validate in Organizer, upload, and complete TestFlight testing before submitting for review.
