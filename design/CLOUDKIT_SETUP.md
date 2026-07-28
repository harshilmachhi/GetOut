# CloudKit Setup

GetOut uses `iCloud.com.parth.getout` as its only backend. Private SwiftData sync and public social are enabled; collaborative trip sharing remains disabled.

## App and signing

1. The App ID is `com.parth.getout` and the development team is configured in `project.yml`.
2. The App ID needs iCloud/CloudKit and Push Notifications capabilities.
3. Use a provisioning profile containing `iCloud.com.parth.getout` and the CloudKit service.
4. Run `xcodegen generate` after project configuration changes.
5. Verify private SwiftData records on two physical devices signed into the same iCloud account.

The CloudKit user record name returned by `CKContainer.userRecordID()` is the canonical GetOut account identifier. There is no phone, Google, email/password, or Sign in with Apple account. Public records can be read without iCloud; creating profiles, posts, and reports requires iCloud.

## Public database schema

Create these record types in the **Development** public database. Field names and types must match exactly.

| Record type | Fields | Required indexes |
|---|---|---|
| `PublicSpot` | `spotID` String, `title` String, `details` String, `latitude` Double, `longitude` Double, `address` String, `city` String, `neighborhood` String, `category` String, `rating` Double, `photo` Asset List, `createdAt` Date/Time, `ownerUserRecordName` String, `ownerDisplayName` String, `ownerUsername` String, `tags` String List, `containsCannabis` Int/Boolean, `countryCode` String, `administrativeArea` String | `createdAt` Queryable + Sortable; `ownerUserRecordName` Queryable |
| `PublicUserProfile` | `userRecordName` String, `username` String, `displayName` String, `bio` String, `avatarSystemImage` String, `createdAt` Date/Time | `username` and `userRecordName` Queryable |
| `PublicReport` | `reporterUserRecordName` String, `targetRecordName` String, `targetOwnerUserRecordName` String, `targetKind` String, `reason` String, `details` String, `status` String, `createdAt` Date/Time | `status` and `targetOwnerUserRecordName` Queryable; `createdAt` Queryable + Sortable |
| `PublicUsernameClaim` | `username` String, `userRecordName` String, `createdAt` Date/Time | `username` and `userRecordName` Queryable |

### Public database security roles

- `PublicSpot`, `PublicUserProfile`, and `PublicUsernameClaim`: World read, Authenticated create, Creator write.
- `PublicReport`: Authenticated create, no World read. Reports are reviewed by the developer in CloudKit Dashboard.

Username claims use deterministic record IDs (`username-<normalized name>`) and CloudKit change-tag conflict handling. This makes the uniqueness check safe when two accounts submit the same username concurrently.
- Do not grant World create/write or Authenticated write to records owned by other creators.

## Validation before production

1. On separate physical devices with different iCloud accounts, create profiles and confirm username collision handling.
2. Publish, page, report, block, unpublish, and delete an account.
3. Confirm a creator cannot edit or delete another creator's records.
4. Confirm public browsing works while signed out of iCloud and all write actions explain that iCloud is required.
5. Confirm cannabis-tagged records contain `tags`, `containsCannabis`, `countryCode`, and `administrativeArea` and remain hidden without eligible age/location state.
6. Review report records daily and delete content that violates the published community guidelines.
7. Confirm a newly published spot with a photo shows the same photo on the second account. A creator device running the migrated build automatically republishes older public spots for which it still has the private photo bytes.
8. Confirm deleting a published spot removes it from the public feed on another device after a refresh.
9. Promote the complete Development schema and indexes to **Production**. App Store builds access only Production.

Do not promote an incomplete schema: production record types and fields can only evolve forward after promotion.

## Feature flags

| Flag | MVP value | Purpose |
|---|---:|---|
| `cloudKitSyncEnabled` | `true` | Private iCloud sync |
| `publicSocialEnabled` | `true` | Public profiles, feed, and reports |
| `collaborativeTripsEnabled` | `false` | Deferred CKShare trip collaboration |
