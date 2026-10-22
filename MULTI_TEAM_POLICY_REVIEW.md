# Team-question policy review draft

**Status: review-only; not applied to Supabase.** The production migration gate remains closed.

## Verified finding

The current `public.team_questions` policy set includes authenticated member-role checks for SELECT and INSERT and an admin-role check for UPDATE, but these policies do not explicitly check `public.teams.is_enabled`. Older permissive policies also coexist with newer restrictive policies, so the effective behavior must be tested as a set.

## Proposed remediation

1. For authenticated SELECT, require the row's team to exist, be enabled, and have a current membership with role member/admin/owner.
2. For authenticated INSERT, require the team to be enabled, `user_id = auth.uid()`, and membership; retain name/question length validation, pending status, and null answer constraints.
3. For UPDATE, require the team to be enabled and the user to have admin/owner membership in both USING and WITH CHECK.
4. Inspect and reconcile the legacy Chenn-only permissive policies only after verifying the app's intended Chenn behavior.
5. Keep anonymous question intake disabled unless a separately reviewed safe public-intake flow is explicitly intended.
6. Test enabled Chenn success, disabled Lev/Gemma denial, cross-team denial, role escalation denial, and existing Chenn regression behavior in staging before production.

## Separate table-grant finding

The `anon` and `authenticated` roles currently have broad table-level grants on `public.teams`, including write and DDL-related privileges. RLS is enabled and there are no policies. Reduce grants only after verifying dependencies; do not add a broad `USING (true)` policy to silence the advisor.

No database changes have been applied. Do not enable Team Lev or Team Gemma as part of this review.
