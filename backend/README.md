# Global leaderboard setup

The game remains on GitHub Pages. Supabase stores scores and exposes two database
RPCs; no Edge Function, paid server, SDK, or service-role key is needed.

1. Create/select a Supabase project. In **SQL Editor**, run all of `schema.sql`.
   This migration is repeatable. It does not erase existing runs.
2. Enable **Authentication → Sign In / Providers → Anonymous Sign-Ins**.
3. From the project Connect/API settings, obtain its **Project URL** and
   **publishable key** (a legacy **anon** key also works). Put only those public
   values in the local `backend-config.js`. Never use a secret/service-role key.
4. Run the local tests, build with `node build-portable.js --pages`, and deploy
   `docs/index.html` to the existing Pages `main /docs` configuration.

Players do not register accounts. Anonymous Auth provides an identity that is
stored in this browser. Names are display labels, not identities. Clearing
storage, changing browsers/devices, or losing the anonymous session creates a
different identity. No cross-device account recovery is promised. The public
leaderboard contains the best run per identity, ordered by score descending,
completion time ascending, then deaths ascending. Date and UUID resolve exact
ties deterministically. Lower-scoring attempts are stored but do not replace a
personal best; the highlighted rank is the player's best run.

## Protection and limitations

Tables have RLS enabled, no public policies, and no direct access for `anon` or
`authenticated`. The read RPC exposes only the top ten and the signed-in user's
best rank, without exposing identity IDs. The submit RPC requires `auth.uid()`;
it checks name/type/size limits, a versioned level reward whitelist, unique and
ordered rewards, all twelve stages, three boss rewards, world completion, death
penalties, and server-calculated speed bonuses. It derives the score and time.
Dates come from the server. Run UUIDs prevent duplicate submissions. Identical
retries return the original result. Maximum five new accepted runs per identity
per ten minutes; Supabase Auth also has its own signup/IP limits.

**This is validation of reported scoring history, not proof of honest gameplay.**
A modified client can fabricate a plausible history, completion time, or new
anonymous identity. The per-identity rate limit is not a global/IP anti-abuse
system. Do not advertise cheat-proof rankings. If abuse becomes significant,
add server-issued run tickets, stronger telemetry verification and signup
CAPTCHA/rate controls as a separate task.

Pending submissions (including run UUID and scoring history), cached scores and
the anonymous session persist in localStorage. Failed submissions retry once
automatically, then expose a Retry button. Refreshing/reloading does not discard
pending scores; the main menu leaderboard can retry them. Blocked browser
storage limits persistence to the open tab. Gameplay remains available when the
backend is offline or unconfigured. Offline cached rankings are labelled.
The pending record is removed only after the server confirms acceptance.

## Verification

`tests/backend.test.js` executes the migration and SQL permissions using local
PostgreSQL (PGlite, test-only). `tests/leaderboard.test.js` checks client persistence,
retries and failures. Browser fixtures are not included in the Pages build.
These do not substitute for a live Supabase/CORS/Auth test after configuration.
No development records should be left in the public backend: use identifiable
test run UUIDs and remove only those specific records through the SQL Editor.
Never enable client DELETE permissions to clean test data.

Reward IDs belong to this scoring/level revision. If level generation or scoring
changes, version the validation rules before publishing to avoid accepting old
clients under new rules. Supabase availability and account quota still apply.

## Secret encounter scoring revision

Before publishing this revision, open the existing Supabase project → SQL Editor
→ New query. Paste the **entire** `backend/migration-secret-storm.sql` file and
click Run. Do not rerun the original `schema.sql` afterward: that would reinstall
the old RPC definitions. Existing projects need only the new migration; a fresh
project needs `schema.sql` first, then this migration. No frontend key changes
are needed. Test live RPCs after applying it before publishing. This release's
live checks verified the revised RPCs, protected tables and submission limits.

This additive migration preserves all existing scores and ranking order, adds
`scoring_version` and `secret_victory`, and keeps RLS/direct-write restrictions.
Old clients keep their original scoring rules. New histories start with
`rules:2` and subtract 2,000 per ordinary death, bounded at zero. Zero-death new
runs must record the concluded secret attempt. Nine ordered weak-point hits
followed by `secret:victory` grant exactly 15,000; failure grants nothing and
does not add a normal death penalty. The indicator is returned by the read RPC.

The server verifies scoring history, qualification, ordered hits, and one final
outcome per run UUID. It cannot prove that a client really performed the fight:
fabricated consistent telemetry remains possible, as with the existing game.
The client saves the attempt before entry; an interrupted/reloaded attempt is
spent and becomes a preserved three-world result, never an arena respawn.
