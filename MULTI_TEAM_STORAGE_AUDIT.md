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
- Policy introspection through SQL was blocked by the safety layer for the Storage policy view. This document records the observed policy behavior from earlier inspection, but a complete authoritative export of the exact Storage policy expressions remains an open prerequisite. Obtain it through the Supabase Dashboard's Storage Policies UI or another authorized supported export method; do not guess or attempt to bypass the restriction.

## Gate remains closed

No Storage policies or bucket settings were changed. Do not enable Team Lev/Gemma until exact policy definitions are reviewed and upload, signed-URL read, update, and delete negative tests pass for each team.
