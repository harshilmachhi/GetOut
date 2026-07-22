# CloudKit Setup

CloudKit is designed into the SwiftData stack but **not enabled** in the current build. All rollout work is gated behind `FeatureFlags` in `GetOut/App/FeatureFlags.swift`. Every flag defaults to `false` — the app ships local-only until you deliberately flip flags and complete portal/signing steps.

## Feature flags (phased rollout)

| Flag | Phase | Owner | What it enables |
|------|-------|-------|-----------------|
| `FeatureFlags.cloudKitSyncEnabled` | Integrator Phase 1 | cloudkit-integrator | Private iCloud sync via `ModelConfiguration(cloudKitDatabase: .private("iCloud.com.parth.getout"))` |
| `FeatureFlags.collaborativeTripsEnabled` | Integrator Phase 2 | cloudkit-integrator | CKShare collaborative trips in the shared CloudKit database |
| `FeatureFlags.publicSocialEnabled` | Public social | cloudkit-public-social | Public CloudKit database for feed, profiles, and following |

`FeatureFlags.effectiveCloudKitSyncEnabled` is derived as `cloudKitSyncEnabled || collaborativeTripsEnabled` — collaborative trips require private sync, so flipping Phase 2 alone still enables the SwiftData CloudKit container. `publicSocialEnabled` does **not** enable the SwiftData container (public DB uses direct CloudKit APIs).

**Phase 0:** flags exist, `project.yml` entitlements/background modes are wired, `GetOutApp.swift` reads `cloudKitDatabaseEnabled` — sync stays off.

**Phase 1:** SwiftData models audited for CloudKit mirroring, demo seeding gated off when CloudKit is enabled, remote-change observer wired — flip `cloudKitSyncEnabled` only after checklist **A** + device signing.

**Phase 2:** CKShare trip collaboration via `TripSharingService` + `UICloudSharingController`, share-accept delegate wired, collaborators UI on trip detail — flip `collaborativeTripsEnabled` (with `cloudKitSyncEnabled`) only after Phase 1 is verified on device.

Do **not** flip flags until the checklist below is complete for that phase.

## Flip-on checklist

### A. One-time Apple Developer Portal + signing

1. Enroll in the Apple Developer Program and note your **Team ID**.
2. In the portal, enable **iCloud** for App ID `com.parth.getout`.
3. Create CloudKit container **`iCloud.com.parth.getout`**.
4. Enable **Push Notifications** (development) for remote CloudKit change notifications.
5. In `project.yml`, set `DEVELOPMENT_TEAM` to your Team ID (replace the empty placeholder).
6. Run `xcodegen generate`.
7. Sign with a development provisioning profile that includes iCloud + CloudKit.

Entitlements are already in `GetOut/GetOut.entitlements`:

- `iCloud.com.parth.getout` container
- CloudKit service
- `aps-environment: development`

`project.yml` already sets:

- `CODE_SIGN_ENTITLEMENTS: GetOut/GetOut.entitlements`
- `INFOPLIST_KEY_UIBackgroundModes: remote-notification`

### B. Phase 1 — private sync (integrator)

1. Complete checklist **A**.
2. Ensure SwiftData models meet CloudKit mirroring rules (defaults on stored properties, optional relationships with inverses, no unique constraints) — **done in Phase 1**.
3. Demo seeding is gated in `SeedData.seedIfNeeded` when `cloudKitSyncEnabled` is true — **done in Phase 1**.
4. Set `FeatureFlags.cloudKitSyncEnabled = true` in `GetOut/App/FeatureFlags.swift`.
5. Build signed for device (`CODE_SIGNING_ALLOWED=YES` with a valid team).
6. Run on a physical device signed into iCloud.
7. Open **CloudKit Dashboard** → container `iCloud.com.parth.getout` → **Development** environment; confirm schema deploy and records after first launch.
8. Test multi-device private sync before shipping.

### C. Phase 2 — collaborative trips (integrator)

Requires Phase 1 private sync on a signed device. Collaborative trips use CloudKit's **shared database** (not the public database). `NSPersistentCloudKitContainer` exposes both private and shared scopes when configured with `.private("iCloud.com.parth.getout")` — no separate ModelConfiguration is needed.

1. Phase 1 verified on device (`cloudKitSyncEnabled = true`).
2. Set **`FeatureFlags.cloudKitSyncEnabled = true`** and **`FeatureFlags.collaborativeTripsEnabled = true`** in `GetOut/App/FeatureFlags.swift`.
3. Build signed for device; ensure both test devices are signed into distinct iCloud accounts.
4. Owner opens a trip → **Share trip** → send invite via the system share sheet (`UICloudSharingController`).
5. Recipient accepts the invite (Mail/Messages link or app open via `userDidAcceptCloudKitShareWith`).
6. Confirm both users can view/edit the shared trip and its stops.
7. In **CloudKit Dashboard** → container `iCloud.com.parth.getout` → **Shared** database (Development), confirm the share root record and participants.

**Implementation notes (code):**

- `TripSharingService` creates/fetches `CKShare` through the underlying `NSPersistentCloudKitContainer` (SwiftData bridge in `SwiftDataCloudKitBridge.swift`).
- Incoming invites are handled by `CloudKitShareAcceptanceDelegate` (`UIApplicationDelegateAdaptor`).
- Shared `Trip` + `TripStop` records mirror through the same SwiftData schema; spots referenced by stops remain in the owner's private database unless also shared separately.

**Dashboard:** No extra container is required beyond checklist **A**. Sharing uses the existing container's shared scope. Deploy the Development schema from a signed device before testing invites.

### D. Public social (cloudkit-public-social agent)

1. Complete checklist **A** (same container; public database is separate from private/shared mirroring).
2. Set `FeatureFlags.publicSocialEnabled = true` only after that agent’s model/service work is merged.
3. Do **not** seed demo public data into real iCloud accounts.

#### Public database schema (Development)

Deploy these record types in **CloudKit Dashboard** → container `iCloud.com.parth.getout` → **Public Database** → **Development** → Schema. Mark listed fields as **Queryable** (and **Sortable** where noted). SwiftData/NSPersistentCloudKitContainer does **not** mirror the public database — the app writes/queries via `CloudKitPublicService` (`CKContainer.publicCloudDatabase`).

| Record type | Record name pattern | Fields | Queryable / sortable indexes |
|-------------|---------------------|--------|------------------------------|
| `PublicSpot` | UUID (generated on publish) | `spotID` (String), `title` (String), `details` (String), `latitude` (Double), `longitude` (Double), `address` (String), `city` (String), `neighborhood` (String), `category` (String), `rating` (Double), `createdAt` (Date/Time), `ownerUserRecordName` (String), `ownerDisplayName` (String), `ownerUsername` (String) | **Queryable + Sortable:** `createdAt` (feed sort, descending). **Queryable:** `ownerUserRecordName` (spots by user). |
| `PublicUserProfile` | `profile-{userRecordName}` | `userRecordName` (String), `username` (String), `displayName` (String), `bio` (String), `avatarSystemImage` (String), `createdAt` (Date/Time) | **Queryable:** `username`, `userRecordName`. |
| `PublicFollow` | `follow-{followerUserRecordName}-{followeeUserRecordName}` | `followerUserRecordName` (String), `followeeUserRecordName` (String), `createdAt` (Date/Time) | **Queryable + Sortable:** `followerUserRecordName`, `followeeUserRecordName`, `createdAt`. |

**Dashboard steps**

1. Open [CloudKit Dashboard](https://icloud.developer.apple.com/) → `iCloud.com.parth.getout` → **Public Database** → **Development**.
2. Add record types `PublicSpot`, `PublicUserProfile`, `PublicFollow` with the fields above (matching field names exactly — see `PublicCloudKitSchema.swift`).
3. For each **Queryable** field in the table, enable **Queryable** in the field editor; enable **Sortable** on `PublicSpot.createdAt` and `PublicFollow.createdAt`.
4. Deploy schema to Development ( **Deploy to Development** ).
5. Run a signed device build with `publicSocialEnabled = true`; publish a spot and confirm records appear under **Public Database** → **Records**.
6. Repeat index/schema review before Production promotion.

**Identity**

- Current user: `CKContainer(identifier: "iCloud.com.parth.getout").userRecordID()` (wrapped by `PublicSocialIdentityService`).
- Optional Sign in with Apple scaffold: `PublicSocialIdentityService.suggestedHandle(from:)` — full SIWA requires paid account + capability.
- Local link: `Profile.cloudKitUserRecordName` stores the CloudKit user record name for cache lookups.

**Local cache**

- Public `CKRecord`s map into SwiftData via `PublicRecordMapping` + `PublicSocialCacheStore` (offline display).
- Extended models (defaults preserve Phase 1 compatibility): `Profile.cloudKitUserRecordName`, `Profile.publicFollowerCount`, `Profile.publicFollowingCount`; `Spot.publicRecordName`, `Spot.publisherUserRecordName`; `Follow.followerUserRecordName`, `Follow.followeeUserRecordName`, `Follow.isPublicSocialFollow`.

**Code entry points**

- Service protocol: `CloudKitPublicService` (`CloudKitPublicServiceLive`, `MockCloudKitPublicService`).
- UI coordinator: `PublicSocialCoordinator` (feed + profile social refresh).
- Discover feed section: `PublicDiscoverFeedSection` (hidden when flag off).
- Profile followers/following: `ProfileView` + `PublicSocialListView` (flag on only).

## Local / simulator builds (no paid account)

Simulator and unsigned builds work with flags off:

```bash
xcodegen generate
xcrun simctl list devices booted   # use the device id, not the name
xcodebuild -project GetOut.xcodeproj -scheme GetOut \
  -destination 'id=<BOOTED_ID>' -configuration Debug \
  -derivedDataPath ./build build CODE_SIGNING_ALLOWED=NO
```

Until checklist **A** is done, keep all `FeatureFlags` at `false`. The app uses **local-only** SwiftData persistence.
