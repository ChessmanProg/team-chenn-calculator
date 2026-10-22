# Team-question and related policy review draft

**Status: review-only; not applied to Supabase.** The production migration gate remains closed.

## Team questions

Authenticated SELECT, INSERT and UPDATE checks do not explicitly require `public.teams.is_enabled`. Legacy permissive policies coexist with restrictive policies.

Proposed remediation: SELECT requires enabled team plus membership; INSERT additionally requires `user_id = auth.uid()` and retains validation for name/question length, Pending status, and null answer; UPDATE requires enabled team and admin/owner membership in both USING and WITH CHECK. Reconcile legacy Chenn-only permissive policies only after verifying intended Chenn behavior. Keep anonymous intake blocked unless a separate safe public intake flow is explicitly intended.

## Question comments — verified inventory

- SELECT: legacy permissive `USING true`, restrictive anon denial, restrictive authenticated membership check.
- INSERT: input validation plus restrictive user ownership, membership, and parent question ID/team match.
- UPDATE: author-only permissive policy plus restrictive membership. Restrictive WITH CHECK requires ownership and membership but does not revalidate parent question/team relation.
- DELETE: author-only permissive policy plus restrictive membership. Preserve author-only deletion; do not grant all team members delete capability.

Proposed remediation: require enabled-team membership for authenticated operations; preserve author-only edit/delete and text/name validation; validate parent question ID/team relation in read and update paths; prevent moving a comment to another parent/team without appropriate authorization. Reconcile policies as a set.

## Announcement read receipts — verified inventory

- SELECT/DELETE: own user ID plus team membership.
- INSERT: ownership, membership, and referenced announcement ID/team match.
- UPDATE: ownership and membership in USING/WITH CHECK, but announcement ID/team relation is not revalidated.
- Policies do not explicitly require the team to be enabled.

Proposed remediation: require enabled-team membership; preserve own-receipt-only semantics; validate announcement ID/team relation in both USING and WITH CHECK for updates, as well as insert. Test changing announcement_id/team_key, another user's receipt, and disabled-team operations.

## public.teams grants

The `anon` and `authenticated` roles have broad table-level grants, including write and DDL-related privileges. RLS is enabled and there are no policies. Reduce grants only after dependency review; do not add a broad `USING (true)` policy.

## Validation gate

Capture complete policy/function/grant definitions; test on staging with real authenticated roles; verify Chenn regression, disabled-team denial, cross-team denial, and preservation of rows/IDs/Storage objects; rerun Security Advisor. No database changes have been applied. Do not enable Team Lev or Team Gemma.
