# GetOut App Store submission handoff

This checklist covers the work that must be completed in Apple portals or on physical devices after the code is archived. Do not submit until every release gate is checked.

## URLs and contact

- Privacy policy: `https://parthdhroovji.me/GetOut`
- Terms and community rules: `https://parthdhroovji.me/GetOut/terms`
- Support, privacy, reporting, and deletion: `parthdhroovji1@gmail.com`
- Verify both URLs return HTTP 200 over HTTPS without a login after the portfolio repository is deployed.

## Suggested App Review notes

> GetOut is an iPhone-only social discovery app backed by the app's CloudKit container. The public feed is readable without an account. Creating a profile, publishing a spot, reporting, or deleting data requires a signed-in iCloud account. The opaque app-specific CloudKit user record ID is the canonical GetOut account identifier; Sign in with Apple, phone, Google, and email/password authentication are not used.
>
> Users publish spots directly. A publication confirmation explains that their profile and exact spot location become public. Users can report a spot or profile from its overflow menu, locally block a creator, unpublish their own spot, and delete their profile and GetOut data in Settings. Reports are reviewed daily at parthdhroovji1@gmail.com and in CloudKit Dashboard.
>
> Cannabis-related content is informational only and does not offer sales, ordering, or delivery. It is hidden unless the user privately confirms legal age and the device is in Canada or California. Publishing a cannabis-tagged spot also requires reverse-geocoded spot coordinates in Canada or California. Location denial and age decline keep this content hidden.

Tell App Review which test iCloud account/profile to use if the reviewer needs to exercise write features. Never include a real Apple ID password in Review Notes; use Apple's supported demo-account process if one is requested.

## App Privacy answers to verify in App Store Connect

Base the final answers on the shipping build and Apple's current definitions. Expected disclosures for this implementation are:

| Data type | Linked to user | Tracking | Purpose |
| --- | --- | --- | --- |
| User ID (opaque CloudKit record ID) | Yes | No | App functionality, account and abuse prevention |
| Name / username / profile bio | Yes | No | App functionality |
| Precise location of published spots | Yes | No | App functionality |
| User content (spot text, tags, reports) | Yes | No | App functionality, safety |
| Photos stored with private spot data | Yes | No | App functionality |
| Coarse/precise viewer location | Review final retention behavior | No | Nearby results and cannabis eligibility |

The app does not track users and does not use data for third-party advertising. Re-check the answers if analytics, crash reporting, ads, or another SDK is added. `PrivacyInfo.xcprivacy` declares the CloudKit-backed data above, no tracking, and the UserDefaults required-reason API; App Store Connect privacy answers are still a separate manual task.

## CloudKit release gate

- Create the public record types, fields, indexes, and security roles in `CLOUDKIT_SETUP.md` in the Development environment.
- Exercise every record type from a development build so CloudKit discovers the private SwiftData schema.
- Verify public read and authenticated/creator write rules with two different iCloud accounts.
- Promote the complete schema to Production only after the fields and indexes are final. Production schema changes are forward-only.
- Confirm the App Store distribution profile includes the production CloudKit container and push entitlement.
- Review `PublicReport` records every day.

## Physical-device and TestFlight matrix

- Account A and B: create distinct profiles; relaunch/reinstall and recover the correct profile from the iCloud identity.
- Attempt the same normalized username from both accounts and verify the second creation is rejected.
- With iCloud signed out: browse public content, then verify profile/post/report actions explain that iCloud is required.
- Publish, page, block, report, unpublish, and delete data. Confirm Account B can no longer resolve Account A after deletion.
- Turn networking off during feed and write operations; verify cached content, error copy, and successful retry.
- Cannabis matrix: Canada, California, an ineligible jurisdiction, age declined, and location denied. Verify both feed visibility and publication.
- Confirm exact-location disclosure appears before every public publication.
- Confirm reports appear in Production CloudKit Dashboard and the support email is reachable.
- Run a full TestFlight pass using the Production schema before review.

## Listing and archive gate

- Use the generated 1024×1024 AppIcon and inspect the archived asset catalog for transparency, text, clipping, or missing slots.
- Capture current iPhone screenshots from the release build with no demo content or placeholder copy.
- Complete name, subtitle, description, keywords, support URL, privacy URL, copyright, category, and age-rating questionnaire.
- Answer the age-rating/cannabis-content questions accurately; do not describe GetOut as enabling cannabis purchases.
- Remove debug/demo records and confirm all visible buttons work in the submitted build.
- Archive with the Release configuration, validate in Organizer, upload, and complete TestFlight testing before submitting for review.
