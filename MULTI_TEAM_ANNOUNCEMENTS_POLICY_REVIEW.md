# Team announcements and comments policy findings

Status: read-only policy inspection; no database changes made.
Project: `jlidwcpklcnpphologhy`

## Confirmed findings

- `team_announcements` has legacy permissive policies for viewing and admin writes, alongside restrictive team-security policies. The restrictive member-read policy requires the row's team to be enabled and the caller to have a member/admin/owner role for that team. Admin writes similarly require an enabled team, a matching role, and for publish, `created_by = auth.uid()`.
- `team_announcement_reads` has restrictive policies that bind receipts to the signed-in user's ID and team membership. The insert policy also checks that the announcement ID and team key match the same announcement row.
- `team_question_comments` has legacy permissive read/write policies paired with restrictive policies. The restrictive read/write policies are important to the effective authorization and must be preserved/reconciled as a set, not replaced piecemeal.
- Storage buckets: `team-announcement-images` is public; `team-question-photos` is private.
- Frontend announcement reads currently omit a `team_key` filter; read receipt queries filter by `user_id` only. The database policy may restrict rows, but the frontend should also query the selected team's key and include it when creating receipts.
- Current announcement publishing/editing UI is based on a global `isTeamChennAdmin` flag. It must become a selected-team role check before more teams can be enabled.

## Implementation implications

1. Add selected-team filtering to announcement list/unread-count queries.
2. Include `team_key` when marking an announcement read, using the announcement's own team key and preserving the composite announcement/team check.
3. Ensure new announcements include the selected `team_key` and the signed-in user's ID as `created_by`.
4. Keep comment access bound to the parent question's team. Verify whether existing comment rows have a valid team key before enforcing additional constraints.
5. Keep public announcement images treated as public URLs; if privacy is required, that would be a separate product decision and migration.

No policies, rows, buckets, or website code were modified by this inspection.
