# Migration history

Migrations are immutable and applied in filename order. Never edit a migration after it has been deployed; create a new timestamped migration instead.

| Migration | Purpose |
| --- | --- |
| `20260908000000_initial_schema.sql` | Complete GetOut schema, indexes, validation, RLS policies, storage bucket, and account-deletion RPC. |
| `20260913000000_circles.sql` | Private Circles, member roles, spot audiences, expiring hashed invites, private photo storage, and membership-enforced RLS. |

Use `supabase db reset` for a clean local replay, `supabase db push --dry-run` to preview a remote deployment, and `supabase db push` to apply pending migrations.
