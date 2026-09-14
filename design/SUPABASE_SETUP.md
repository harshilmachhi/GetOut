# Supabase setup

Supabase is GetOut's only remote backend. The hosted project reference is `wnhafdejexuzebwoglja`; SwiftData is only an on-device cache.

## Reproducible schema and history

- `supabase/config.toml` contains the safe-to-commit local service configuration.
- `supabase/migrations/` is the authoritative, ordered SQL history.
- `supabase/MIGRATIONS.md` summarizes each migration.
- Never edit a deployed migration. Add a later timestamped migration with `supabase migration new <name>`.

For a clean local replay:

```bash
supabase start
supabase db reset
```

To deploy the checked-in history:

```bash
supabase login
supabase link --project-ref wnhafdejexuzebwoglja
supabase db push --dry-run
supabase db push
supabase migration list
```

The CLI requires a Supabase access token and the project database password. Neither belongs in source control.

## Required dashboard settings

1. In Authentication → Providers, keep Anonymous Sign-Ins disabled.
2. Enable Apple. In Apple Developer, enable Sign in with Apple for App ID `com.parth.getout`, then add `com.parth.getout` to the Supabase Apple provider's Client IDs.
3. Enable Google. Create a Google OAuth **Web application** client whose authorized redirect URI is `https://wnhafdejexuzebwoglja.supabase.co/auth/v1/callback`, then add its client ID and secret to the Supabase Google provider.
4. In Authentication → URL Configuration → Redirect URLs, add `getout://login-callback`.
5. Apply the migrations. They create all tables, RLS policies, grants, indexes, the public `spot-photos` bucket, the private `circle-spot-photos` bucket, Circle invite RPCs, and `delete_my_account()`.
6. Confirm the publishable key under Project Settings → API Keys matches `SupabaseConfig.publishableKey`.

The publishable key ships in the app by design. It is not a secret; authorization is enforced through Supabase Auth, grants, and RLS. Never add a secret or service-role key to the app.

## Identity behavior

The app requires Sign in with Apple or Continue with Google before profile creation. Supabase persists the authenticated session in the iOS keychain. A returning user is matched by the stable Supabase Auth UUID, never by an editable username. Signing out removes cached account data from the device; deleting an account also calls `delete_my_account()` to remove its Auth user and owned database rows.

Provider credentials and dashboard toggles are deployment configuration, not SQL, so they cannot live in a migration. The exact required values are recorded above; all database state remains reproducible from `supabase/migrations/`.

## Verification

Use two clean simulator installations:

1. Sign in once with Apple and once with Google; create distinct profiles and verify a duplicate normalized username is rejected.
2. Publish a spot with photos; verify public reads work and only its owner can update/delete it.
3. Exercise likes, saves, ratings, trips, stops, blocks, and reports.
4. Relaunch and confirm private state is restored from Supabase.
5. Delete the account in Settings and confirm its Auth user, profile, owned rows, and storage objects are gone.
6. Run `supabase db reset` in local development to prove the checked-in history recreates the schema.

For Circles, test with three signed-in accounts: an owner, a member, and a non-member. Confirm the member can load a Circle-only spot and its signed photo, the non-member cannot select either row or object, removal hides the spot on the next refresh, expired/revoked links fail, and public + Circle spots remain available publicly.
