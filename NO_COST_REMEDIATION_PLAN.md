# Multi-team security remediation — no-cost workflow

Status: review/preparation only. No paid Supabase branch created. No production database or Storage changes applied.

## No-cost validation plan

1. Keep Team Lev and Team Gemma disabled.
2. Prepare coordinated SQL migration drafts in GitHub and review function signatures, existing policies, grants, and Storage behavior before applying.
3. Run static checks on the proposed SQL and compare against the live schema using read-only queries.
4. Apply changes to production only after the SQL is reviewed and the user understands that without an isolated staging database, runtime regression testing is limited. Prefer user-provided local/staging database or a free test project if available.
5. After any approved application, run targeted read-only verification and Supabase Security Advisor again. Check existing Chenn calculator, schedules, meeting links, questions/comments, announcements, and object references.
6. Never enable Lev/Gemma until memberships, team-enabled enforcement, Storage path authorization, and cross-team denial tests are verified.

## Priority fixes to prepare

- Meeting-link RPCs: preserve signatures and Chenn admin/owner checks; validate each schedule ID exists and belongs to Chenn before read, upsert, or delete.
- Generic team questions/comments/announcement reads: reconcile overlapping permissive and restrictive policies; add enabled-team checks and parent-row consistency while preserving anon intake restrictions, author-only comment deletion, and own-receipt semantics.
- Storage: keep team-question photos private and retain 5 MB/extension restrictions; design an upload flow compatible with the frontend uploading before the question row exists. Confirm whether public announcement images are intentionally public before multi-team reuse.
- public.teams: narrow excessive table grants only after verifying application dependencies.
- SECURITY DEFINER functions: inspect EXECUTE grants one by one; no blanket revoke.
- Auth: consider leaked-password protection after checking signup/reset compatibility.

No-cost constraint: do not create a billable Supabase branch or project. Production remains unchanged until an explicit, informed decision to apply a reviewed migration.
