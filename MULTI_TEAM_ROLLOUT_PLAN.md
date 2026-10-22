# Multi-Team Workspace Rollout Plan

Status: preparation only. This document does not change the live database or enable Team Lev / Team Gemma.

## Non-negotiable safety rules

- Keep `main` and the live GitHub Pages site unchanged until a reviewed pull request is ready.
- Keep the existing Team Chenn records intact.
- Do not enable Lev or Gemma until both database policies and frontend queries enforce team separation.
- Do not run a broad SQL policy cleanup. Legacy permissive policies can combine with newer policies in ways that are not obvious.
- Do not expose protected meeting URLs through public schedule rows.

## Current blockers identified in the existing app

1. The browser uses a single `isTeamChennAdmin` flag and the `is_team_chenn_admin` RPC.
2. Coaching meeting links use `get_team_chenn_meeting_links` and `save_team_chenn_meeting_link`, which authorize Team Chenn roles and address links by schedule ID only.
3. Data loaders for schedules, IC logs, important links, questions, comments, announcements, and announcement read receipts do not consistently constrain reads/writes by a selected team.
4. Several older RLS policies are permissive or Chenn-specific. Frontend filters alone are not a security boundary.
5. Storage upload policies for announcement images and question photos are Chenn-specific.
6. The `teams` table currently has Chenn enabled and Lev/Gemma disabled; only Chenn memberships were present in the inspected state.

## Implementation sequence

### Phase A — Frontend team context (no database writes)
- Introduce one explicit active-team state and team metadata.
- Keep Chenn as the only enabled workspace in the interface.
- Route team-specific labels and admin UI through the active team instead of assuming Chenn.
- Do not allow Lev/Gemma to load shared Chenn data as a temporary fallback.

### Phase B — Database migration draft (review before execution)
- Prepare team-aware authorization functions and RLS policies for each table.
- Replace or neutralize conflicting legacy permissive policies only after every replacement policy is verified.
- Make protected meeting-link functions verify team membership and ensure a schedule belongs to the same team.
- Update storage policies to verify the selected record's team and caller's team role.
- Preserve existing Chenn rows and behavior. Avoid bulk updates of existing rows unless a reviewed migration proves they are required.

### Phase C — Team-specific application queries
- Scope selects, inserts, updates, and deletes for schedules, IC logs, important links, questions, comments, announcements, and read receipts to the active team.
- Scope announcement and question-photo storage paths and authorization.
- Ensure Chenn's existing screens and records still work.

### Phase D — Controlled activation and validation
- Add approved Lev/Gemma memberships and enable each team only after migration and app changes are deployed.
- Test with separate accounts: a member of one team must not read, edit, delete, or upload data for another team.
- Test Chenn admin controls, meeting-link privacy, questions/comments, announcements/read receipts, logout, and reload.
- Merge to `main` only after review and passing checks.

## Release gate

No team other than Chenn should be enabled until cross-team access tests pass. If a test fails, keep the new teams disabled and correct the policies before release.

## Database audit update — 2026-10-22

Read-only inspection confirmed the following live database state:

- `public.teams` contains Chenn (enabled), Lev (disabled), and Gemma (disabled).
- Existing data remains in Chenn's core tables: 15 coaching schedules, 4 IC logs, and 9 important links.
- RLS is enabled on the core tables, but that alone does not guarantee isolation.
- Legacy permissive SELECT policies with `USING (true)` remain on `coaching_schedules`, `ic_logs`, `important_links`, and `team_announcements`. These must be reconciled with the team-membership policies before any new workspace is enabled.
- Existing admin policies and meeting-link RPC functions are Chenn-specific. Meeting links are stored in `private.coaching_meeting_links` and require a reviewed team-aware replacement that verifies the schedule's `team_key`.
- The current frontend uses `isTeamChennAdmin`, and its loaders do not uniformly apply a selected-team filter. A database-only change would therefore be insufficient.
- Supabase security advisors also flagged callable SECURITY DEFINER functions and disabled leaked-password protection. Function grants need to be reviewed individually; do not blanket-revoke functions the current site depends on.

### Safe next implementation gate

1. Build a table-by-table migration draft and review existing policy/function definitions.
2. Update all affected frontend reads and writes on this feature branch.
3. Apply database changes only after the draft and dependencies have been reviewed; then run advisors and cross-team access tests.
4. Keep Lev and Gemma disabled until every test passes.

No database schema, policies, memberships, team enablement, or existing data were changed during this audit.

## Follow-up function and RLS review — 2026-10-22

Supabase documentation was reviewed before planning changes: https://supabase.com/docs/guides/database/postgres/row-level-security

Read-only function inspection confirms:

- `public.has_team_role(team_key, roles)` checks the authenticated user's row in `private.team_memberships`.
- `get_team_chenn_meeting_links()` and `save_team_chenn_meeting_link(schedule_id, meet_link)` currently authorize Chenn admins/owners only.
- The current meeting-link functions operate on schedule IDs but do not independently verify that the referenced schedule belongs to the authorized team.
- `delete_own_team_question` is a SECURITY DEFINER function with an owner-token check; it should not be changed as part of a generic policy cleanup without a separate compatibility/security review.

### Do not apply a broad policy rewrite yet

The existing policies include both permissive and restrictive policy types. PostgreSQL combines permissive policies with OR and restrictive policies with AND, so reviewing only a policy's name or `USING` expression is not enough to determine the effective access. The migration must be tested against the full set of policies, including legacy tables and storage objects.

Before any production migration:
- Inventory all policies on every exposed table, including the legacy question table, question comments, announcements, announcement reads, and PPH records.
- Inventory storage policies for announcement images and question photos.
- Verify current role grants and function EXECUTE grants.
- Prepare a rollback strategy and test the migration against a disposable/staging project if available.
- Confirm the Chenn account can still read and write all intended data after the change.
- Test that an account without a Lev/Gemma membership cannot read, write, or access meeting links for those teams.
- Only then add approved memberships and enable each workspace.

This follow-up was inspection and documentation only. No database policies, functions, grants, memberships, or team enablement were changed.
