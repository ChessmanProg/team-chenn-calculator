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
