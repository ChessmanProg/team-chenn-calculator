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


### Comment deletion policy — focused re-check

A fresh focused read of the effective `public.team_question_comments` policy definitions clarifies the delete behavior: the only permissive DELETE policy is `Users can delete their own comments` (`auth.uid() = user_id`), and the restrictive DELETE policy additionally requires the caller to have a role on that comment's team. Since permissive policies are ORed and restrictive policies are ANDed, a signed-in team member can delete **their own** comment, but this policy set does not grant members a general ability to delete other people's comments. No separate admin-delete exception is present in the listed policy set. Preserve this author-only behavior unless the product owner explicitly chooses to add team-admin moderation.

The same focused policy read confirms:
- Comment SELECT has a legacy permissive `USING (true)` but a restrictive policy denies anonymous reads and requires team membership for authenticated users.
- Comment INSERT requires `user_id = auth.uid()`, valid name/comment lengths, membership on `team_key`, and a matching `team_questions` row with the same question ID and team key.
- Comment UPDATE requires ownership in both the permissive policy and restrictive `WITH CHECK`, plus team membership.

These are read-only policy findings; no policy was changed.


## Storage policy audit update (2026-10-22; documentation only)

### `team-announcement-images` (public bucket)

The supplied INSERT, UPDATE USING, UPDATE WITH CHECK, and DELETE USING expressions all require `is_team_chenn_admin()`. These are Chenn-specific. The object path convention is `<announcement-id>/<timestamp>.<extension>`, so a replacement must resolve the first path segment to the announcement row and validate the row's `team_key` plus the caller's role for that team. The bucket is public: mutation RLS does not make public object URLs private.

### `team-question-photos` (private bucket)

The supplied SELECT expression matches `objects.name` to `team_questions.photo_url` and checks `has_team_role(q.team_key, ['member','admin','owner'])`. The supplied INSERT expression restricts extensions to JPG/JPEG/PNG/WebP and checks a role for the literal team key `chenn`; it is therefore not ready for Lev/Gemma.

Frontend inspection of `index.html` confirms `submitTeamQuestion()` uploads `question-photos/<random-uuid>.<extension>` before inserting the `team_questions` row. This means a policy that depends on the future question row cannot authorize that initial upload. The design must establish and validate the intended team at upload time (for example, a team-scoped object path enforced server-side or a server-side upload flow), and later verify that the question row references only an authorized object. Keep the current file type and 5 MB checks. A failed question insert may leave an orphan object; cleanup must be a separate, conservative task with a retention period and backup, not a bulk deletion during migration.

### Required staging tests before opening the gate

- Chenn member/admin can upload and view only photos linked to questions in teams they belong to.
- Lev/Gemma members can upload only after their team is enabled and they have the intended role; they cannot reference a question or object belonging to another team.
- Direct Storage requests cannot bypass the frontend checks.
- Announcement image insert/update/delete is authorized against the announcement row's team, including attempts to change object paths or target another team's announcement ID.
- Public announcement image URL visibility is explicitly accepted as a product decision.
- Failed question insert does not silently accumulate unlimited orphaned uploads; cleanup respects the approved retention window.

No SQL was added or executed by this audit. Migration gate remains CLOSED.


## Additional read-only policy and function inventory (2026-10-22)

Queried `pg_policies` for the main team-scoped tables and inspected `pg_proc` security-definer flags plus EXECUTE privileges. This was read-only; no policies or functions were changed.

### Policy findings requiring resolution

- `coaching_schedules`, `ic_logs`, and `important_links` retain permissive Chenn-admin write policies and permissive `SELECT USING (true)` policies alongside restrictive policies. For authenticated users, the restrictive member-access policies require an enabled team and membership; writes require an enabled team and admin/owner. Anonymous roles have restrictive `false` policies. Keep the policy set intact until all operations and effective behavior are tested.
- `team_questions` has legacy permissive `SELECT USING (true)` and permissive INSERT for `anon, authenticated`; restrictive policies block anon and constrain authenticated reads to team membership, but the SELECT restrictive predicate does not itself check `teams.is_enabled`. A membership in a disabled team may therefore still satisfy that specific gate. This must be tested and corrected in the migration design before enabling new teams.
- `team_question_comments` has a permissive public SELECT plus restrictive anon block and team-member SELECT check. The restrictive SELECT checks membership against the comment's `team_key` but does not explicitly require the parent question's `team_key` to match; INSERT does check the parent question ID/team pair. Validate existing rows and ensure SELECT/UPDATE/DELETE predicates consistently bind comments to their parent question's team.
- `team_question_comments` DELETE has a permissive own-comment policy and a restrictive team-membership policy; effective access allows a team member to delete comments in their team, not just their own comments. Confirm whether this moderation behavior is intended before migration.
- `team_announcement_reads` has user-owned permissive policies and restrictive team-aware policies. INSERT verifies the referenced announcement ID and team_key match; SELECT/UPDATE/DELETE checks membership and ownership as applicable. UPDATE's restrictive predicate does not itself revalidate the announcement relationship, so test row mutation attempts and consider an explicit invariant.
- `team_announcements` has legacy permissive public SELECT and permissive Chenn-admin write policies, with restrictive policies that block anon and require enabled-team membership for authenticated reads and team admin/owner for writes. Effective authenticated access is constrained by the restrictive policies, but legacy rules complicate review and should be consolidated carefully.
- `team_chenn_questions` has legacy permissive user INSERT plus Chenn-admin policies and restrictive team-aware policies; inspect the exact column/team behavior and preserve compatibility for this legacy table.
- `agent_pph_records` has a user-owned permissive policy and restrictive member access that requires enabled team plus team membership. Verify whether `user_id` ownership is meant to restrict reads/writes further or whether all team members are intended to access all records.

### Security-definer function/grant findings

The following functions are marked `SECURITY DEFINER` and are executable by `authenticated` but not `anon`: `private.is_team_chenn_admin()`, `public.delete_own_team_question(bigint,text)`, `public.get_team_chenn_meeting_links()`, `public.has_team_role(text,text[])`, `public.is_team_chenn_admin()`, `public.is_team_chenn_owner()`, `public.owner_grant_team_chenn_admin(uuid)`, `public.owner_revoke_team_chenn_admin(uuid)`, and `public.save_team_chenn_meeting_link(bigint,text)`. `public.rls_auto_enable()` is not executable by anon or authenticated. This query confirms effective role grants but does not establish that function bodies are safe. Before rollout, inspect function bodies, fixed `search_path` behavior, and owner-grant/revoke authorization. Meeting-link RPCs remain Chenn-specific and must validate the referenced schedule's team.

### Current conclusion

This read-only inventory identified specific migration blockers: disabled-team question access may not be explicitly blocked by the current question SELECT predicate; comment SELECT is not explicitly tied to the parent question team; and comment DELETE's effective rule appears broader than author-only deletion. Do not apply a policy rewrite until these are tested against intended behavior and existing data.
