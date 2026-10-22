# Team-aware migration draft — review required

Status: DRAFT ONLY. Do not apply to the live database yet.
Project: `jlidwcpklcnpphologhy`
Target code branch: `feature/multi-team-workspaces`

## Confirmed schema facts

- `public.teams(team_key, display_name, is_enabled, created_at)`
- `private.team_memberships` contains the team membership and role assignments.
- `public.coaching_schedules`, `ic_logs`, `important_links`, `agent_pph_records`, `team_questions`, `team_question_comments`, `team_announcements`, and `team_announcement_reads` have team-key columns or team-linked scope.
- `private.coaching_meeting_links` stores a meeting link keyed by `schedule_id`; the schedule row is the authoritative team association.
- Current frontend RPCs `get_team_chenn_meeting_links` and `save_team_chenn_meeting_link` are SECURITY DEFINER and Chenn-specific.

## Migration requirements

1. Before changing policies, export the complete current policy definitions and function bodies/grants for every affected table/function.
2. Preserve all existing rows with `team_key = 'chenn'` where they currently default to or are assigned to Chenn. Do not reassign historical records to Lev/Gemma.
3. Add/verify team-key constraints and foreign-key relationships only after checking existing values and nullability.
4. Implement a team-aware admin predicate that validates `auth.uid()`, the requested team, the membership role, and `teams.is_enabled`.
5. Implement team-aware meeting-link read/write RPCs that verify the caller has an allowed role for the team and that the referenced schedule row belongs to that same team. Do not authorize by schedule ID alone.
6. Replace Chenn-only Storage write policies with team-aware policies after establishing a verified object-path convention and linking each object to a row in its own team.
7. Reconcile permissive and restrictive policies as a set. PostgreSQL combines permissive policies with OR and restrictive policies with AND; adding one policy is not sufficient proof of isolation.
8. Keep Lev/Gemma disabled until the negative cross-team tests pass.

## Validation checklist

- Snapshot row counts and existing IDs before and after migration.
- Confirm the two existing Chenn memberships can still read/write exactly what they could before, subject to existing roles.
- Confirm a Chenn member cannot read, edit, delete, or fetch meeting links for Lev/Gemma records.
- Confirm a Lev member cannot read, edit, delete, or fetch meeting links for Chenn/Gemma records, and vice versa.
- Confirm disabled teams reject access even when a membership row exists.
- Confirm Storage upload, select, update, and delete isolation for both buckets.
- Run Supabase security and performance advisors after applying in a disposable/staging environment first.

## Why this is not executable SQL yet

The full effective policy set, function bodies and EXECUTE grants, storage object path convention, and all frontend write paths must be verified together before authoring an executable migration. Applying a guessed policy rewrite could accidentally widen access or break the working Chenn site. This file is a gated implementation checklist, not a migration and has not been applied.


## Additional read-only findings (2026-10-22)

### Effective-policy risks to resolve

The current public-schema policy inventory confirms legacy permissive policies remain alongside team-aware restrictive policies:

- `team_announcements`: legacy permissive read policy uses `USING (true)`; older write policies call `is_team_chenn_admin()`. Team-aware restrictive policies exist, but the complete policy set must be evaluated together. Do not infer isolation from the newer policy names alone.
- `team_questions`: legacy permissive SELECT uses `true`, and a legacy permissive INSERT policy allows anonymous/authenticated submission. Restrictive policies currently block anonymous access and require team membership for authenticated rows. Verify the resulting effective behavior for each role before removing or replacing any rule.
- `team_question_comments`: legacy permissive SELECT uses `true`; legacy insert/update/delete policies coexist with restrictive team-aware policies. The current team-aware DELETE restriction checks team membership, not explicitly comment authorship, while a legacy permissive rule limits the user-owned path. Decide and test the intended policy: author-only deletion, team-admin deletion, or both.
- `team_announcement_reads`: legacy permissive user-owned policies coexist with restrictive policies that bind receipts to a team membership. Keep the receipt's `announcement_id` and `team_key` tied to the same announcement row.

### Storage object-path findings

The current frontend builds announcement image paths as `<announcement-id>/<timestamp>.<extension>`. The path does not contain a team key. Therefore, storage policies should look up the associated announcement row and verify its `team_key` plus the caller's team role. Do not adopt a team-prefix policy without a coordinated path migration and preservation plan.

Announcement image objects are served from the public `team-announcement-images` bucket using public URLs. Authorization on upload/update/delete does not make already-public image URLs private. This is acceptable only if the product owner intends announcement images to be publicly viewable.

Question-photo upload and read policies must be reconciled against the exact frontend upload path and the `team_questions.photo_url` representation before drafting replacements. Preserve existing object names/URLs unless a migration explicitly updates references safely.

### Meeting-link RPC requirements

The existing SECURITY DEFINER functions `get_team_chenn_meeting_links()` and `save_team_chenn_meeting_link(p_schedule_id bigint, p_meet_link text)` authorize against Chenn roles. The saved link row is keyed by `schedule_id`, so every read/write must join to `public.coaching_schedules`, derive its `team_key`, verify that team is enabled, and verify the caller's allowed role for that same team. Keep old function signatures compatible until frontend call sites are switched and tested; do not revoke EXECUTE grants blindly.

### Current safe rollout status

- This file remains a planning draft, not executable SQL.
- No database DDL, policy, function, storage object, team enablement, or live deployment was changed during this review.
- Team Lev and Team Gemma must remain disabled until policy and storage isolation tests pass.
- Some storage-policy introspection queries were blocked by the database safety layer. Do not bypass that restriction; use supported dashboard exports or authorized policy review to obtain the missing definitions.


### Question-photo and question-deletion findings

The question-photo upload path currently uses `question-photos/<random-uuid>.<ext>` inside the private `team-question-photos` bucket. The database row stores that relative object path in `team_questions.photo_url`; the frontend requests a signed URL after loading the question. Storage policy design should resolve the stored path to a `team_questions` row and validate the row's team and the caller's role. Because the object path itself has no team key or question ID, avoid authorizing from path prefix alone. Confirm whether an upload can be orphaned when the question insert fails, and plan safe cleanup without deleting objects referenced by existing rows.

The `public.delete_own_team_question(bigint,text)` SECURITY DEFINER function checks that a signed-in user supplies a sufficiently long owner token whose SHA-256 hash matches `team_questions.owner_token_hash`, then deletes that question. It does not currently check team membership or `teams.is_enabled`; the owner token is the primary authorization check. Before altering this behavior, test compatibility with questions posted from devices whose local ownership token is unavailable. Any team-aware replacement should preserve the intended “original poster can delete” flow while preventing cross-team side effects and ensuring the photo cleanup is safe.

### Remaining audit items before executable migration

1. Obtain the full Storage policy definitions using a supported dashboard/policy export route; database query attempts were blocked, and no replacement policy should be guessed.
2. Verify the complete grants and function definitions for any RPCs called by the legacy question panel, including the owner-token delete RPC.
3. Decide whether comments may be deleted by authors only or by team admins as well, and document the choice.
4. Verify question-photo upload rollback/orphan cleanup and the relationship between each object path and its question row.
5. Complete role-by-role effective-policy tests in a disposable/staging environment before any production migration.
