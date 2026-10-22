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
