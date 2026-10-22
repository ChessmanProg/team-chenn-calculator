# Frontend team-scope audit — multi-team rollout

Status: inspection only; no frontend code or live site changed.
Branch: `feature/multi-team-workspaces`

## Current code paths to update before enabling new teams

- Coaching schedules, IC logs, important links, and PPH records are loaded from shared tables. Several reads rely on RLS and do not explicitly filter by the selected team.
- Meeting links still use `get_team_chenn_meeting_links` and `save_team_chenn_meeting_link`; these are Chenn-named RPCs and must be replaced or wrapped by reviewed team-aware functions that validate the schedule's team.
- Announcement reads query `team_announcements` without a team filter; read receipts query by user ID but do not include team context in the frontend query.
- Team question comments are loaded by `question_id`; their access must remain bound to the parent question's team via database policy.
- The admin UI relies on the global `isTeamChennAdmin` flag. A selected workspace will need role checks scoped to the selected team, not a global Chenn admin flag.
- Existing question and announcement forms need to include the selected team key when creating records. Existing Chenn records must remain assigned to `chenn`.

## Safe implementation order

1. Finish the effective-policy and function-grant inventory.
2. Draft database migration and rollback scripts, including team-aware meeting-link RPCs and storage policies.
3. Add selected-team state and explicit team filters to frontend reads/writes while Lev/Gemma remain disabled.
4. Test Chenn regression behavior and verify cross-team access denial with separate accounts.
5. Only after all tests pass, enable new teams in a separately approved rollout.

## Safety boundary

No database migration, policy, record, account, storage object, or live website was changed by this audit.
