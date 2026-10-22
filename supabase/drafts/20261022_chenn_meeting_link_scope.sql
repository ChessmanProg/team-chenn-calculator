-- DRAFT ONLY — do not apply to production until reviewed.
-- Purpose: constrain existing Chenn-specific meeting-link RPCs to Chenn schedules.
-- Preserves both public function signatures and the existing auth/URL validation.

CREATE OR REPLACE FUNCTION public.get_team_chenn_meeting_links()
RETURNS TABLE(schedule_id bigint, meet_link text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
BEGIN
    IF auth.uid() IS NULL
       OR NOT public.has_team_role('chenn', ARRAY['admin', 'owner'])
    THEN
        RAISE EXCEPTION 'Not authorized to view meeting links'
            USING ERRCODE = '42501';
    END IF;

    RETURN QUERY
    SELECT l.schedule_id, l.meet_link
    FROM private.coaching_meeting_links AS l
    JOIN public.coaching_schedules AS s
      ON s.id = l.schedule_id
    WHERE s.team_key = 'chenn';
END;
$function$;


CREATE OR REPLACE FUNCTION public.save_team_chenn_meeting_link(
    p_schedule_id bigint,
    p_meet_link text
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
BEGIN
    IF auth.uid() IS NULL
       OR NOT public.has_team_role('chenn', ARRAY['admin', 'owner'])
    THEN
        RAISE EXCEPTION 'Not authorized to manage meeting links'
            USING ERRCODE = '42501';
    END IF;

    IF p_schedule_id IS NULL THEN
        RAISE EXCEPTION 'Schedule ID is required';
    END IF;

    -- Reject missing schedules and schedules belonging to another team,
    -- including when the caller requests deletion via a blank link.
    IF NOT EXISTS (
        SELECT 1
        FROM public.coaching_schedules AS s
        WHERE s.id = p_schedule_id
          AND s.team_key = 'chenn'
    ) THEN
        RAISE EXCEPTION 'Schedule not found for Team Chenn'
            USING ERRCODE = '22023';
    END IF;

    IF p_meet_link IS NULL OR btrim(p_meet_link) = '' THEN
        DELETE FROM private.coaching_meeting_links
        WHERE schedule_id = p_schedule_id;

        RETURN true;
    END IF;

    IF p_meet_link !~* '^https?://' THEN
        RAISE EXCEPTION 'Meeting link must start with http:// or https://';
    END IF;

    INSERT INTO private.coaching_meeting_links (schedule_id, meet_link)
    VALUES (p_schedule_id, p_meet_link)
    ON CONFLICT (schedule_id)
    DO UPDATE SET meet_link = EXCLUDED.meet_link;

    RETURN true;
END;
$function$;

-- Validation checklist before applying:
-- 1. Confirm function owners and EXECUTE grants remain unchanged after replacement.
-- 2. Verify a Chenn admin can read/save/delete a Chenn schedule link.
-- 3. Verify a Chenn admin cannot read or mutate a non-Chenn schedule link.
-- 4. Verify missing schedule IDs are rejected for save and delete.
-- 5. Verify non-admin/member/anonymous calls remain denied.
-- 6. Confirm frontend schedule creation + RPC sequence still succeeds.
-- 7. Compare link rows before/after; this migration must not delete any existing rows.
