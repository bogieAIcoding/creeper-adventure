# Creeper Adventure

A client-side Canvas platformer with three worlds, twelve stages, original
procedural graphics and synthesized music. The GitHub Pages entry is
`docs/index.html`: one self-contained file, with no external assets or runtime
asset requests. The optional global leaderboard uses Supabase.
`.nojekyll` bypasses unnecessary Jekyll processing.

All twelve stages and regular bosses are included. Completing all three worlds
with zero deaths unlocks the cinematic and one-attempt Wither Storm encounter.
Its victory grants 15,000 points and the true ending; ordinary deaths subtract
2,000 points, bounded at zero. Interrupted secret attempts are spent. Apply
`backend/migration-secret-storm.sql` before publishing this scoring revision.
The local `wither-storm-test.html` and all development shortcuts are excluded
from the published build.

## Play

Use landscape orientation and tap **START GAME** to unlock audio. Hold Left or
Right to run; hold Jump for height, release and tap again to double jump. Pause
is in the HUD; Retry, volume sliders and mute are above the game. Returning
from another app leaves the game paused: tap Resume.

Choose NORMAL or HARD above Start Game; difficulty stays locked for that run.
Courses use a reproducible seed, and checkpoint retries keep the same layout.
HARD adds three enemies per stage, new telegraphed creatures, faster platforms
and tougher double-jump sections. Gem trails keep deliberate rows and arcs.
The HUD shows score and unique defeated enemies (KO); respawned enemies cannot
be farmed for extra score or KO credit. NORMAL/HARD rankings are separate, as
are generator revisions. Apply `backend/migration-procedural.sql` before
publishing this build. Existing scores are preserved in their original pool.

Desktop: A/D or arrows move, Space/W/Up jumps, Shift runs, Esc/P pauses,
R retries, M mutes. F optionally requests fullscreen where supported.

The iPad layout handles desktop-style user agents, visible Safari toolbar
resizing and safe-area insets. Portrait displays a rotation message. Fullscreen
and orientation locking are not required. Actual iOS and Android hardware
testing is still required. Reloading starts a new game; checkpoints persist
within the running session. Once loaded, gameplay works without the network;
the optional global leaderboard uses Supabase. Offline page reload is not
promised. Pending completed scores and cached rankings persist in this browser
where storage is available. See `backend/README.md` for backend setup and limits.

## Publish / update

The development files stay in the local project. From that project, run:

```
node build-portable.js --pages
node --test tests/*.test.js
git add docs backend DEPLOYMENT.md .gitignore
git commit -m "Update Creeper Adventure"
git push origin main
```

Configure GitHub **Settings → Pages → Deploy from a branch → main → /docs**.
Use GitHub's displayed HTTPS URL after its deployment finishes; verify that
the deployed HTML matches the local build. Only the generated site, this guide
and the ignore rules are intended for publication; development screenshots,
temporary tests, private files and credentials are excluded.
