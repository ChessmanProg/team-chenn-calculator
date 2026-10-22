# Multi-team security remediation plan

Status: REVIEW PLAN ONLY — NOT EXECUTABLE SQL; NOT APPLIED TO SUPABASE.

Project: `jlidwcpklcnpphologhy`
Branch: `feature/multi-team-workspaces`
Rollout gate: CLOSED
Team Chenn remains enabled. Team Lev and Team Gemma remain disabled.

## Safety rules

- Do not change production policies, functions, grants, team enablement, storage objects, or records until the exact current definitions are captured and a complete replacement is reviewed.
- Do not drop/recreate policies based on policy names alone. PostgreSQL combines permissive policies with OR and restrictive policies with AND; test the effective behavior for anon, authenticated member, admin, owner, disabled team, and cross-team cases.
- Keep current Chenn rows and IDs unchanged. Do not bulk-move data or delete Storage objects.
- Keep old RPC signatures until frontend callers are migrated and regression-tested.
- Test proposed SQL on a disposable/staging database first; run a rollback/restore rehearsal before production.

## Finding-to-action register

### 1. Team enablement enforcement

Affected: `team_questions`, `team_question_comments`, `team_announcement_reads`, and any team-aware policies/functions missing an enabled-team predicate.

Action:
- Define one consistent rule: a user must be authenticated, have the required role for the row's team, and that team must have `is_enabled = true`.
- Apply it to SELECT, INSERT, UPDATE (both USING and WITH CHECK), and DELETE where the operation exists.
- For child rows, also verify the parent row belongs to the same team and the parent team's enabled status is true.
- Do not enable Lev/Gemma just because policy SQL has been drafted.

Acceptance tests:
- A member in a disabled team cannot select or mutate its rows.
- A Chenn user cannot access Lev/Gemma rows and vice versa.
- UPDATE cannot move a row across teams by changing `team_key`.
- Anonymous requests remain denied wherever the current application requires login.

### 2. Meeting-link RPCs and schedule integrity

Affected: `private.coaching_meeting_links`, `public.get_team_chenn_meeting_links()`, `public.save_team_chenn_meeting_link(bigint,text)`.

Verified schema: `public.coaching_schedules` has primary key `id`; the inspected constraints did not show a foreign key from `private.coaching_meeting_links.schedule_id` to `public.coaching_schedules.id`.

Action:
- Before every read/write, join the link to `public.coaching_schedules` and derive the authoritative `team_key` from the schedule.
- Verify the team is enabled and the caller has admin/owner role for that exact team.
- Validate the schedule exists. For writes/deletes, never authorize from a caller-supplied schedule ID alone.
- Decide whether a foreign key is appropriate only after checking orphan rows and the intended delete behavior. Do not add a constraint until the existing data is checked.
- Keep existing Chenn RPC signatures as compatibility wrappers until frontend callers are switched and tested; do not turn the old Chenn RPC into a general team RPC without a deliberate API design.

Acceptance tests:
- Missing schedule IDs fail safely.
- A Chenn admin cannot read/write another team's meeting link by guessing an ID.
- Deleting/archiving a schedule has the explicitly chosen link behavior and does not silently orphan links.

### 3. Storage policy authorization

Affected buckets: public `team-announcement-images`; private `team-question-photos`.

Announcement images:
- Current object path is `<announcement-id>/<timestamp>.<extension>`, without a team prefix.
- Resolve the announcement ID to its row; check that row's team is enabled and caller has admin/owner role for that same team for INSERT/UPDATE/DELETE.
- Validate UPDATE USING and WITH CHECK so an object cannot be moved to another team's announcement path.
- Public bucket URLs are public to anyone who has the URL; Storage mutation policies do not make them private. Confirm public visibility is intended.

Question photos:
- Current path is `question-photos/<random-uuid>.<extension>`; the question row is inserted after upload, so an authorization policy that requires a future question row cannot authorize the initial upload.
- Choose and test a coordinated upload design before writing replacement policies: preferably an authenticated server-side upload flow or a team-scoped upload intent/path that is validated against a real membership and cannot be spoofed to cross teams.
- Preserve the 5 MB limit and JPG/JPEG/PNG/WebP restrictions.
- On reads, verify the object is referenced by a question row and the user has an enabled-team role for that row's team.
- Failed inserts can leave orphan uploads. Design conservative delayed cleanup with a retention period and reference check; never bulk-delete existing objects during the migration.

Acceptance tests:
- Direct Storage API calls cannot bypass team authorization.
- Users cannot upload to, overwrite, delete, or sign URLs for another team's content.
- Existing Chenn photo paths still work after the change.
- No existing referenced object is deleted by cleanup.

### 4. RLS-enabled tables without policies

Security Advisor reported RLS enabled with no policies for:
- `private.coaching_meeting_links`
- `private.team_chenn_admins`
- `private.team_chenn_owner`
- `private.team_memberships`
- `public.teams`

Action:
- Verify schema exposure, grants, function access, and actual application access paths for each table.
- Confirm `private` is not an exposed API schema and that direct roles do not have table privileges that would bypass the intended function-mediated access.
- For `public.teams`, decide whether authenticated users need a read-only list of enabled teams. If so, create a narrow SELECT policy and grants; do not grant direct writes. If team listing is function-mediated, verify that path instead.
- Do not add blanket `USING (true)` policies to silence the advisor.

Acceptance tests:
- Anon/authenticated direct table access behaves as intended.
- Membership writes remain restricted to trusted owner/admin functions or a separately approved admin workflow.
- The UI can read only the team metadata it needs.

### 5. SECURITY DEFINER function grants

Advisor warned that authenticated users can execute SECURITY DEFINER functions. This is a warning to review, not proof of a vulnerability.

Functions to review:
- `public.delete_own_team_question(bigint,text)`
- `public.get_team_chenn_meeting_links()`
- `public.has_team_role(text,text[])`
- `public.is_team_chenn_admin()`
- `public.is_team_chenn_owner()`
- `public.owner_grant_team_chenn_admin(uuid)`
- `public.owner_revoke_team_chenn_admin(uuid)`
- `public.save_team_chenn_meeting_link(bigint,text)`
- `private.is_team_chenn_admin()`

Action:
- Retain SECURITY DEFINER only where it is required to safely access private membership data or implement a narrowly scoped operation.
- Keep a fixed safe `search_path` and schema-qualify referenced objects.
- Inspect each function's exact authorization checks and grant matrix. Revoke EXECUTE only after confirming the frontend does not depend on it and after replacement behavior is tested.
- Keep owner grant/revoke functions Chenn-owner-scoped; they are not generic multi-team membership managers.
- For owner-token question deletion, preserve the intended original-poster flow, verify token generation and grants, and add team/parent consistency only where it will not break existing legitimate deletions.
- `has_team_role` may be intentionally callable by authenticated users; it returns a boolean but should remain tightly defined and should include the enabled-team rule where used for authorization.

Acceptance tests:
- Unauthenticated execution fails where appropriate.
- Ordinary authenticated users cannot grant/revoke memberships or manipulate meeting links.
- Owners can administer only the team the function is designed to administer.
- Existing question deletion continues to work for legitimate owners.

### 6. Password protection

Security Advisor reports leaked-password protection disabled.

Action:
- Review the Supabase Auth password-security setting and enable leaked-password protection if available for this project and compatible with the current signup UX.
- This is an Auth dashboard setting, not a reason to alter application data or database policies.

Acceptance test:
- A known compromised password is rejected by Auth; ordinary signup/login and password reset still work.

### 7. Policy behavior and compatibility

Before authoring executable SQL:
- Capture the complete current policy definitions (schema, command, permissive/restrictive mode, roles, USING, WITH CHECK) and function definitions/grants.
- Reconcile old and new policies as a set rather than layering additional rules without proving effective access.
- Preserve the current intended comment behavior: the focused re-check reported the permissive DELETE policy is author-only and restrictive membership is additionally required. Re-run effective-policy verification because an earlier inventory note described broader behavior; do not change moderation semantics without an explicit decision.
- For comments and read receipts, verify the parent ID/team relationship in both read and update paths, not only insert.
- Confirm intended `agent_pph_records` ownership semantics: whether records are private to `user_id` or shared with team members. Preserve current effective behavior until product intent is confirmed.
- Confirm whether `coaching_schedules`, `ic_logs`, and `important_links` should be private to authenticated team members or publicly readable. Current restrictive anon policies deny anon even though legacy permissive SELECT policies say true.

## Rollout gate checklist

Gate stays CLOSED until all items pass:
- [ ] Exact current schema, policies, functions, grants, and Storage policies exported.
- [ ] Existing Chenn row counts and IDs snapshotted and preserved.
- [ ] Migration reviewed as a whole; no guessed policy names or unverified dependencies.
- [ ] Staging/disposable run succeeds and rollback is rehearsed.
- [ ] Chenn login/logout, calculator, schedules, IC logs, links, questions, comments, announcements, photos, and meeting links regression-tested.
- [ ] Negative cross-team tests pass for every table, RPC, and Storage operation.
- [ ] Disabled-team tests pass even if a test membership exists.
- [ ] Security Advisor findings are reviewed again; remaining warnings are documented with rationale.
- [ ] Only after approval: enable Lev/Gemma separately, with a controlled test and rollback plan.

No production database changes are authorized by this document.