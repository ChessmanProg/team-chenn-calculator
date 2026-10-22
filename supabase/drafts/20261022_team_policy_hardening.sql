-- DRAFT ONLY — do not apply to production until the complete policy set is reviewed.
-- Adds enabled-team and parent-row checks to the existing restrictive policies.
-- Existing permissive policies and validation checks are intentionally not dropped here;
-- policy reconciliation must be done as a coordinated migration after regression review.

-- Helper pattern used below:
-- EXISTS (SELECT 1 FROM public.teams t
--         WHERE t.team_key = <row>.team_key AND t.is_enabled IS TRUE)
--
-- TEAM QUESTIONS: replace restrictive policies with enabled-team-aware checks.
DROP POLICY IF EXISTS "Team members only: read questions" ON public.team_questions;
CREATE POLICY "Team members only: read questions"
ON public.team_questions AS RESTRICTIVE FOR SELECT TO authenticated
USING (
  public.has_team_role(team_key, ARRAY['member','admin','owner'])
  AND EXISTS (
    SELECT 1 FROM public.teams t
    WHERE t.team_key = team_questions.team_key AND t.is_enabled IS TRUE
  )
);

DROP POLICY IF EXISTS "Team members only: submit questions" ON public.team_questions;
CREATE POLICY "Team members only: submit questions"
ON public.team_questions AS RESTRICTIVE FOR INSERT TO authenticated
WITH CHECK (
  user_id = (SELECT auth.uid())
  AND public.has_team_role(team_key, ARRAY['member','admin','owner'])
  AND EXISTS (
    SELECT 1 FROM public.teams t
    WHERE t.team_key = team_questions.team_key AND t.is_enabled IS TRUE
  )
);

DROP POLICY IF EXISTS "Team admins only: update questions" ON public.team_questions;
CREATE POLICY "Team admins only: update questions"
ON public.team_questions AS RESTRICTIVE FOR UPDATE TO authenticated
USING (
  public.has_team_role(team_key, ARRAY['admin','owner'])
  AND EXISTS (
    SELECT 1 FROM public.teams t
    WHERE t.team_key = team_questions.team_key AND t.is_enabled IS TRUE
  )
)
WITH CHECK (
  public.has_team_role(team_key, ARRAY['admin','owner'])
  AND EXISTS (
    SELECT 1 FROM public.teams t
    WHERE t.team_key = team_questions.team_key AND t.is_enabled IS TRUE
  )
);

-- COMMENTS: enabled team + parent question/team consistency.
DROP POLICY IF EXISTS "Team members only: read comments" ON public.team_question_comments;
CREATE POLICY "Team members only: read comments"
ON public.team_question_comments AS RESTRICTIVE FOR SELECT TO authenticated
USING (
  public.has_team_role(team_key, ARRAY['member','admin','owner'])
  AND EXISTS (
    SELECT 1 FROM public.teams t
    WHERE t.team_key = team_question_comments.team_key AND t.is_enabled IS TRUE
  )
  AND EXISTS (
    SELECT 1 FROM public.team_questions q
    WHERE q.id = team_question_comments.question_id
      AND q.team_key = team_question_comments.team_key
  )
);

DROP POLICY IF EXISTS "Team members only: add comments" ON public.team_question_comments;
CREATE POLICY "Team members only: add comments"
ON public.team_question_comments AS RESTRICTIVE FOR INSERT TO authenticated
WITH CHECK (
  user_id = (SELECT auth.uid())
  AND public.has_team_role(team_key, ARRAY['member','admin','owner'])
  AND EXISTS (
    SELECT 1 FROM public.teams t
    WHERE t.team_key = team_question_comments.team_key AND t.is_enabled IS TRUE
  )
  AND EXISTS (
    SELECT 1 FROM public.team_questions q
    WHERE q.id = team_question_comments.question_id
      AND q.team_key = team_question_comments.team_key
  )
);

DROP POLICY IF EXISTS "Team members only: edit comments" ON public.team_question_comments;
CREATE POLICY "Team members only: edit comments"
ON public.team_question_comments AS RESTRICTIVE FOR UPDATE TO authenticated
USING (
  user_id = (SELECT auth.uid())
  AND public.has_team_role(team_key, ARRAY['member','admin','owner'])
  AND EXISTS (
    SELECT 1 FROM public.teams t
    WHERE t.team_key = team_question_comments.team_key AND t.is_enabled IS TRUE
  )
  AND EXISTS (
    SELECT 1 FROM public.team_questions q
    WHERE q.id = team_question_comments.question_id
      AND q.team_key = team_question_comments.team_key
  )
)
WITH CHECK (
  user_id = (SELECT auth.uid())
  AND public.has_team_role(team_key, ARRAY['member','admin','owner'])
  AND EXISTS (
    SELECT 1 FROM public.teams t
    WHERE t.team_key = team_question_comments.team_key AND t.is_enabled IS TRUE
  )
  AND EXISTS (
    SELECT 1 FROM public.team_questions q
    WHERE q.id = team_question_comments.question_id
      AND q.team_key = team_question_comments.team_key
  )
);

DROP POLICY IF EXISTS "Team members only: delete comments" ON public.team_question_comments;
CREATE POLICY "Team members only: delete comments"
ON public.team_question_comments AS RESTRICTIVE FOR DELETE TO authenticated
USING (
  user_id = (SELECT auth.uid())
  AND public.has_team_role(team_key, ARRAY['member','admin','owner'])
  AND EXISTS (
    SELECT 1 FROM public.teams t
    WHERE t.team_key = team_question_comments.team_key AND t.is_enabled IS TRUE
  )
);

-- ANNOUNCEMENT READ RECEIPTS: own receipt only, enabled team, matching announcement.
DROP POLICY IF EXISTS "Team security: members read own receipts" ON public.team_announcement_reads;
CREATE POLICY "Team security: members read own receipts"
ON public.team_announcement_reads AS RESTRICTIVE FOR SELECT TO authenticated
USING (
  user_id = (SELECT auth.uid())
  AND public.has_team_role(team_key, ARRAY['member','admin','owner'])
  AND EXISTS (
    SELECT 1 FROM public.teams t
    WHERE t.team_key = team_announcement_reads.team_key AND t.is_enabled IS TRUE
  )
  AND EXISTS (
    SELECT 1 FROM public.team_announcements a
    WHERE a.id = team_announcement_reads.announcement_id
      AND a.team_key = team_announcement_reads.team_key
  )
);

DROP POLICY IF EXISTS "Team security: members create own receipts" ON public.team_announcement_reads;
CREATE POLICY "Team security: members create own receipts"
ON public.team_announcement_reads AS RESTRICTIVE FOR INSERT TO authenticated
WITH CHECK (
  user_id = (SELECT auth.uid())
  AND public.has_team_role(team_key, ARRAY['member','admin','owner'])
  AND EXISTS (
    SELECT 1 FROM public.teams t
    WHERE t.team_key = team_announcement_reads.team_key AND t.is_enabled IS TRUE
  )
  AND EXISTS (
    SELECT 1 FROM public.team_announcements a
    WHERE a.id = team_announcement_reads.announcement_id
      AND a.team_key = team_announcement_reads.team_key
  )
);

DROP POLICY IF EXISTS "Team security: members update own receipts" ON public.team_announcement_reads;
CREATE POLICY "Team security: members update own receipts"
ON public.team_announcement_reads AS RESTRICTIVE FOR UPDATE TO authenticated
USING (
  user_id = (SELECT auth.uid())
  AND public.has_team_role(team_key, ARRAY['member','admin','owner'])
  AND EXISTS (
    SELECT 1 FROM public.teams t
    WHERE t.team_key = team_announcement_reads.team_key AND t.is_enabled IS TRUE
  )
  AND EXISTS (
    SELECT 1 FROM public.team_announcements a
    WHERE a.id = team_announcement_reads.announcement_id
      AND a.team_key = team_announcement_reads.team_key
  )
)
WITH CHECK (
  user_id = (SELECT auth.uid())
  AND public.has_team_role(team_key, ARRAY['member','admin','owner'])
  AND EXISTS (
    SELECT 1 FROM public.teams t
    WHERE t.team_key = team_announcement_reads.team_key AND t.is_enabled IS TRUE
  )
  AND EXISTS (
    SELECT 1 FROM public.team_announcements a
    WHERE a.id = team_announcement_reads.announcement_id
      AND a.team_key = team_announcement_reads.team_key
  )
);

-- IMPORTANT REVIEW ITEMS BEFORE APPLYING:
-- 1. Validate the installed Postgres version/policy interactions and policy names.
-- 2. Keep anonymous access denied for these three tables.
-- 3. Reconcile permissive legacy policies as a set; restrictive policies do not replace
--    permissive policies, and UPDATE/DELETE author-only behavior must remain.
-- 4. Test row-level operations as anon, ordinary member, Chenn admin, and disabled-team user.
-- 5. Do not apply until SQL has been tested on an isolated database.
