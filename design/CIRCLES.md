# Circles

Circles are private, shared place maps for trusted groups. A spot can be visible globally, in one or more Circles, or in both places. The feature shipped under the name **Circles** because it communicates a small trusted audience and reads naturally in the map filter and sharing flow.

## Product behavior

- Create and manage Circles from Profile → Circles.
- Invite people with a system share link. Recipients must sign in before accepting.
- Invite links contain 192 bits of randomness, are stored only as SHA-256 hashes, expire after seven days, allow at most 25 joins, and can be revoked by an owner or admin.
- Circle owners can remove members. Members can leave. Owners can delete the Circle.
- While adding a spot, choose Public, one or more Circles, or both. A spot cannot be submitted with no audience.
- The map source switch supports All, Public, and each Circle. Private spots also carry a visible lock/Circle label elsewhere in the app.
- Sharing a private spot through the system share sheet does not include its address.

The interaction model borrows the understandable parts of Signal group links, Discord's limited and expiring invites, and Google Maps shared lists while keeping GetOut's exact-location data behind database authorization:

- https://support.signal.org/hc/en-us/articles/360051086971-Group-Link-or-QR-code
- https://support.discord.com/hc/en-us/articles/208866998-Invites-101
- https://support.google.com/maps/answer/7280933

## Data model

- `circles`: ownership and presentation metadata.
- `circle_members`: membership and `owner`, `admin`, or `member` role.
- `circle_invites`: hashed, expiring, limited-use, revocable invite capabilities.
- `spot_circles`: many-to-many spot sharing destinations.
- `spots.is_public`: global visibility, defaulting to `true` for backward compatibility.
- `circle-spot-photos`: private Storage bucket for Circle-only photos.

The authoritative schema is `supabase/migrations/20260913000000_circles.sql`. Do not edit it after deployment; create a later migration for future changes.

## Security boundaries

Postgres row-level security is the authorization boundary. Client-side filters are only presentation.

- Anonymous users can select only `spots.is_public = true`.
- Signed-in users can select a private spot only when they own it or currently belong to at least one linked Circle.
- A non-member cannot discover a Circle, enumerate its roster, or select its spot links.
- Only a spot owner who belongs to a Circle can link that spot to the Circle.
- Only owners/admins can create or revoke invites; invite tables have no direct client grants.
- Private photo reads require access to the corresponding spot. The app issues five-minute signed URLs only after that check.
- Only public spots enter the persistent offline cache. Signing out immediately removes private spots from in-memory state.
- Ratings use the spot's access policy so their IDs cannot reveal private spot activity.

Removing a member blocks new database and Storage requests immediately. A photo URL already signed for an authorized member can remain usable for up to five minutes and may remain in the operating system's image cache; this is the bounded trade-off of displaying private Supabase Storage objects in React Native.

## Deployment record

- Deployed on 2026-09-13 to Supabase project `wnhafdejexuzebwoglja`.
- `supabase db push --linked --dry-run` reported only `20260913000000_circles.sql` pending.
- `supabase db push --linked --yes` applied the migration successfully.
- `supabase migration list --linked` confirmed local and remote migration `20260913000000` match.
- `supabase db lint --linked --level warning --fail-on error` reported no schema errors.
- Anonymous REST smoke tests returned `200` for public spot selection and `401` for direct Circle selection.

## Verification

Automated checks:

```bash
npm run typecheck
npm run lint
npx expo export --platform android
git diff --check
```

The RLS regression suite is `supabase/tests/circles_rls.sql`. Run it after starting Docker Desktop:

```bash
supabase start
supabase db reset --local --no-seed
supabase test db
```

Manual end-to-end QA requires three real test accounts on two devices or simulator installations:

1. As the owner, create a Circle and share an invite link.
2. Open the link as a second signed-in account, accept it, and confirm the Circle appears.
3. Publish one Circle-only spot and one Public + Circle spot with photos.
4. Confirm the member can see both spots and filter the map to the Circle.
5. Confirm a third non-member cannot open the Circle-only spot URL, query its row, or load its photo.
6. Remove the member, refresh their app, and confirm the Circle, exact location, and new photo requests disappear.
7. Revoke invite links and confirm an unused old link fails. Also verify an expired or fully-used invite fails.
8. Confirm the Public + Circle spot remains visible when signed out and the Circle-only spot does not remain in the offline cache.

## Operational notes

- The database migration is already live, but the mobile client changes still need the normal app build/release process.
- Deep links use the registered `getout://` scheme. Universal/App Links are not configured, so recipients need GetOut installed for the smoothest invite experience.
- Deleting a Circle does not delete member-authored spots. Spots shared only to that Circle become visible only to their creator until they are shared elsewhere or deleted.
- There is no destructive down migration. If rollback is required, first ship a client that no longer writes Circle data, then create a forward migration that preserves or exports private content before removing schema objects.
