# Storage policy audit — multi-team rollout

Status: READ-ONLY FINDINGS; no storage policies changed.
Project: `jlidwcpklcnpphologhy`
Branch: `feature/multi-team-workspaces`

## Findings

The current Storage policies are still partly Chenn-specific:

- `team-announcement-images` upload, update, and delete policies use `is_team_chenn_admin()`. These need team-aware authorization and a reliable way to associate each object with its team before enabling additional teams.
- `team-question-photos` upload policy explicitly checks `has_team_role('chenn', ...)`; it must be redesigned to derive and validate the team through the related question/object path rather than hardcoding Chenn.
- The `View linked team question photos` SELECT policy checks that an object name matches `team_questions.photo_url` and that the user has a role for that question's team. This is closer to team-aware behavior, but it must be checked against the upload path and any URL/path conventions used by the frontend.
- Announcement images are in a public bucket, so object URL visibility is public by design; RLS on object mutations does not make already-public image URLs private.

## Required before enabling Lev/Gemma

1. Confirm the exact object naming convention for each bucket and whether it contains a team key.
2. Update upload/read/update/delete policies together; do not change only upload.
3. Ensure a user cannot upload to one team's namespace while referencing another team's question or announcement.
4. Preserve current Chenn objects and links during any migration.
5. Test authenticated cross-team attempts and unauthenticated attempts, then run the Supabase security advisor.

## Safety boundary

This is documentation, not SQL. No bucket configuration, storage object, policy, database record, or live deployment was changed.

## Additional path verification (2026-10-22)

- Announcement uploads use `<announcement-id>/<timestamp>.<extension>`. The path does not contain a team key. A safe replacement policy must look up `team_announcements` using the announcement ID represented by the first path segment and verify the row's team and caller role for upload/update/delete.
- Question uploads use `question-photos/<random-uuid>.<extension>` in the private bucket. The database stores that relative object path in `team_questions.photo_url`; the frontend generates signed URLs only after loading the row. The object name alone does not identify the team, so policy authorization should join the object path to a question row and verify its team membership.
- The frontend uploads a question photo before inserting the question row. If the row insert fails, the current visible flow does not show a compensating removal of the uploaded object. This may leave orphaned objects. A cleanup plan should be designed and tested separately; do not bulk-delete unreferenced objects without a reviewed retention window and backup.
- Policy introspection through SQL was blocked by the safety layer for the Storage policy view. Do not bypass this restriction.

## Dashboard policy inventory supplied by the user (2026-10-22)

The Dashboard listing confirms these policy names, commands, and role scopes. Exact expressions are recorded below when supplied; expressions for other policies are still needed.

### `team-announcement-images` (public bucket)

| Policy name | Command | Applied to | Expression status |
|---|---|---|---|
| Team announcement admins upload images | INSERT | authenticated | Known; see below |
| Team announcement admins update images | UPDATE | authenticated | Known; USING and WITH CHECK supplied; see below |
| Team announcement admins delete images | DELETE | authenticated | Still needed |

**INSERT policy expression supplied by user:**

```sql
((bucket_id = 'team-announcement-images'::text) AND is_team_chenn_admin())
```

**UPDATE policy expressions supplied by user:**

USING:
```sql
((bucket_id = 'team-announcement-images'::text) AND is_team_chenn_admin())
```

WITH CHECK:
```sql
((bucket_id = 'team-announcement-images'::text) AND is_team_chenn_admin())
```

These expressions are explicitly Chenn-admin-only because they call `is_team_chenn_admin()`. They do not authorize Team Lev or Team Gemma admins. They also do not verify that the first path segment identifies an existing announcement belonging to the same team as the uploader. The eventual replacement should bind authorization to the referenced announcement row and its team, rather than simply replacing the Chenn helper with a team role check.

### `team-question-photos` (private bucket)

| Policy name | Command | Applied to | Expression status |
|---|---|---|---|
| View linked team question photos | SELECT | authenticated | Still needed |
| Upload team question photos | INSERT | authenticated | Still needed |

The policy names and role scope alone are not sufficient to validate authorization. For UPDATE, both `USING` and `WITH CHECK` must be reviewed. The exact expressions are still needed to determine whether each policy is Chenn-only, correctly team-scoped, and safe against cross-team object references. The user may provide the policy detail panel's full expressions or an authorized policy export; no SQL bypass is needed.

## Gate remains closed

No Storage policies or bucket settings were changed. Do not enable Team Lev/Gemma until exact policy expressions are reviewed and upload, signed-URL read, update, and delete negative tests pass for each team.
