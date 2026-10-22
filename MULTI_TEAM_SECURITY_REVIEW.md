# Multi-team security review — meeting links and Storage

Status: review-only. No database or Storage policy changes have been applied.

## Meeting links

Verified functions: public.get_team_chenn_meeting_links() and public.save_team_chenn_meeting_link(bigint,text) are SECURITY DEFINER, set an empty search_path, and authorize a signed-in Chenn admin/owner. They do not validate the schedule's team before reading or modifying private.coaching_meeting_links.

Read-only snapshot: 15 meeting-link rows; zero orphaned schedule IDs and zero rows joined to non-Chenn schedules at audit time.

Remediation design: preserve signatures and Chenn-specific authorization; before returning or changing a link, verify the schedule exists and public.coaching_schedules.team_key = 'chenn'. Reject missing/non-Chenn IDs for both save and delete. Regression-test the existing UI call path before applying.

## Storage policy findings

team-question-photos (private):
- SELECT permits reading a stored object when its path matches team_questions.photo_url and the user has member/admin/owner role for that question's team. It does not explicitly check teams.is_enabled.
- INSERT currently hardcodes Chenn membership and allows jpg/jpeg/png/webp extensions. It does not verify a team-scoped upload intent or a corresponding question row. This may be intentional because the UI uploads the photo before inserting the question; changing it to require an existing row could break uploads.
- A safe multi-team design must authorize the intended team before upload, bind the object path to that team/question flow, preserve the 5 MB limit, keep the bucket private, and clean up only verified unreferenced uploads after a retention window. Do not bulk-delete objects.

team-announcement-images (public):
- INSERT/UPDATE/DELETE are gated by is_team_chenn_admin(), a Chenn-specific helper, but policies do not verify an announcement row or team in the object path.
- Because the bucket is public, object viewing is public regardless of these write policies. Confirm that public visibility is intended before multi-team reuse.

## Other confirmed risks

- public.team_questions SELECT/INSERT/UPDATE policies do not consistently enforce teams.is_enabled.
- team_question_comments and team_announcement_reads have older permissive policies alongside restrictive policies; preserve author-only comment deletion and own-receipt semantics, while adding enabled-team and parent-record consistency checks.
- anon and authenticated have broad table grants on public.teams despite RLS and no policies; narrow after dependency verification.
- Security Advisor reported authenticated EXECUTE on several SECURITY DEFINER functions and leaked-password protection disabled. Review grants function-by-function; do not blanket-revoke. Consider enabling leaked-password protection after confirming signup/reset compatibility.

## Release gate

Do not enable Team Lev or Team Gemma. Capture current definitions, test the coordinated migration on staging with representative users, verify Team Chenn flows and cross-team/disabled-team denial, check row/object preservation, then rerun Security Advisor. Production remains unchanged until an approved, tested migration is ready.
