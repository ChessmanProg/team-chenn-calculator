# Multi-team migration gate

Status: DRAFT ONLY — NOT APPLIED TO SUPABASE.

Project: `jlidwcpklcnpphologhy`
Branch: `feature/multi-team-workspaces`

## Why this is not an executable migration yet

Read-only inspection confirms that the existing database has a mix of permissive and restrictive RLS policies. A policy with `USING (true)` can still affect access when combined with other permissive policies. The legacy `team_questions` table and `team_question_comments` include broad SELECT policies, while team membership rules are restrictive. The exact effective policy set must be inventoried for each table before removing or replacing any policy.

The current coaching, IC-log, and important-link tables have Chenn-specific permissive write policies plus restrictive team-membership checks. Meeting-link RPCs are Chenn-specific and use a schedule ID without independently checking the schedule's team. Replacing these functions without a complete compatibility test risks breaking Chenn or crossing team boundaries.

## Verified current facts

- Team Chenn is enabled.
- Team Lev and Team Gemma are disabled.
- Existing team memberships are Chenn-only.
- Existing records must remain associated with Chenn.
- The website currently rejects opening Lev/Gemma.
- Frontend queries for schedules, IC logs, important links, questions, and announcements need explicit team context in addition to RLS.
- Question comments must be scoped by the parent question's team.
- Storage policy expressions are now recorded in `MULTI_TEAM_STORAGE_AUDIT.md`. Announcement image upload/update/delete policies are Chenn-admin-only; question-photo upload is Chenn-role-only; question-photo SELECT is linked to the question row and checks that row's team membership. Storage policy review is still not sufficient to authorize enabling Lev/Gemma because the upload flow and table policies must be changed and tested together.

## Required migration work before any execution

1. Export every policy for each relevant table with schema, command, permissive/restrictive mode, roles, USING, and WITH CHECK.
2. Review the supplied Storage expressions and design team-aware policies for all operations. For question photos, redesign upload sequencing/path authorization because the object is uploaded before its question row exists. For announcement images, authorize against the announcement row identified by the object path. Preserve public-bucket behavior unless separately approved.
3. Inventory table grants and EXECUTE grants for every SECURITY DEFINER RPC.
4. Draft replacement policies table-by-table. Preserve intended Chenn behavior; restrict all reads/writes to enabled teams and authorized memberships.
5. Replace Chenn-only meeting-link RPCs with team-aware versions that verify the schedule belongs to the requested team.
6. Update frontend queries and inserts to pass/filter the selected team; do not treat UI checks as security.
7. Test Chenn reads/writes and negative cross-team access before granting new memberships or enabling Lev/Gemma.
8. Review the exact migration and rollback plan before applying it.

## Safety boundary

This file is documentation only. Do not run it as SQL. No database policies, functions, grants, memberships, team enablement, or live-site deployment are changed by this draft.

## Updated audit status (2026-10-22)

### Confirmed

- Comment DELETE currently requires the authenticated user's own `user_id` under the permissive policy plus team membership under the restrictive policy. No team-admin moderation exception appears in the focused policy listing. Preserve author-only deletion unless explicitly changed by product decision.
- Comment UPDATE requires ownership and team membership; INSERT requires matching question/team and authenticated ownership.
- Announcement image object names are `<announcement-id>/<timestamp>.<extension>`; question-photo object names are `question-photos/<random-uuid>.<extension>`.
- Question-photo upload occurs before the question row insert; the frontend flow inspected does not show compensating object deletion if the insert fails, so orphan cleanup needs a separate safe design.
- The owner-token question delete RPC verifies a SHA-256 token hash and signed-in session; changing it needs compatibility tests.
- User-provided Dashboard policy inventory:
  - Public bucket `team-announcement-images`: `Team announcement admins upload images` (INSERT), `Team announcement admins update images` (UPDATE), `Team announcement admins delete images` (DELETE), all applied to `authenticated`.
  - Private bucket `team-question-photos`: `View linked team question photos` (SELECT), `Upload team question photos` (INSERT), applied to `authenticated`.
- The policy list did not include the expressions, so it does not yet prove the rules are safely team-scoped.

### Still blocking an executable migration

- Finish the Storage/table-policy design and tests, including cross-team object references and question-photo upload failure/orphan handling. Expressions supplied so far are documented in `MULTI_TEAM_STORAGE_AUDIT.md`; any additional UPDATE/DELETE policies for question photos or other Storage policies must also be inventoried if present.
- Review all table policies and grants together, including legacy permissive policies, before authoring replacement SQL.
- Prepare staging tests for existing Chenn behavior, enabled-team checks, disabled-team denial, meeting-link isolation, question-photo signed URLs, announcement image writes, and comment author/admin behavior.
- Define rollback steps and verify a recoverable backup/snapshot before any production DDL.

### Explicit no-change statement

This update is documentation only. No Supabase schema, policies, functions, grants, data, storage objects, team memberships, enabled-team flags, or live deployment was changed. The migration gate remains CLOSED.


### Storage audit update (2026-10-22)

- User supplied the exact INSERT, UPDATE USING/WITH CHECK, and DELETE USING expressions for `team-announcement-images`. All three use `is_team_chenn_admin()` and therefore remain Chenn-admin-only. The object path is `<announcement-id>/<timestamp>.<extension>`; future authorization must validate the referenced announcement row and team.
- User supplied `team-question-photos` SELECT expression: it matches `objects.name` to `team_questions.photo_url` and checks the caller's role for `q.team_key`.
- User supplied `team-question-photos` INSERT expression: it restricts extension to JPG/JPEG/PNG/WebP and requires a role in `chenn`, so Lev/Gemma uploads would be denied.
- Frontend inspection confirms question photo upload currently precedes insertion of the `team_questions` row. A team-aware redesign must safely establish the target team before upload; do not just remove the hardcoded Chenn check. Failed inserts may leave orphan objects, so cleanup must be separate and conservative.
- These are documentation-only findings. No live Storage policy, database record, membership, team flag, or deployment changed. Migration gate remains CLOSED.
