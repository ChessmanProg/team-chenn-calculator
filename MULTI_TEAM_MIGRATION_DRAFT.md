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
