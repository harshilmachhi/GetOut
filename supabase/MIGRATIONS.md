# Migration history

Migrations are immutable and applied in filename order. Never edit a migration after it has been deployed; create a new timestamped migration instead.

| Migration | Purpose |
| --- | --- |
| `20260908000000_initial_schema.sql` | Complete GetOut schema, indexes, validation, RLS policies, storage bucket, and account-deletion RPC. |
| `20260913000000_circles.sql` | Private Circles, member roles, spot audiences, expiring hashed invites, private photo storage, and membership-enforced RLS. |
| `20260914000000_allow_circle_owner_read.sql` | Allow a Circle owner to read the inserted Circle before its owner-membership trigger is visible to `INSERT ... RETURNING`. |
| `20260915000000_merge_saved_into_loved.sql` | Merge Saved spots into Loved, move visit history to `been_there`, and remove Saved data and schema. |
| `20260916000000_spot_community.sql` | Add Circle-aware spot comments and written reviews, harden rating writes, and support reporting community content. |

Use `supabase db reset` for a clean local replay, `supabase db push --dry-run` to preview a remote deployment, and `supabase db push` to apply pending migrations.
