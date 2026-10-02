# Creeper Adventure

A client-side Canvas platformer with three worlds, twelve stages, original
procedural graphics and synthesized music. The GitHub Pages entry is
`docs/index.html`: one self-contained file, with no external assets or runtime
network requests. `.nojekyll` bypasses unnecessary Jekyll processing.

## Play

Use landscape orientation and tap **START GAME** to unlock audio. Hold Left or
Right to run; hold Jump for height, release and tap again to double jump. Pause
is in the HUD; Retry, volume sliders and mute are above the game. Returning
from another app leaves the game paused: tap Resume.

Desktop: A/D or arrows move, Space/W/Up jumps, Shift runs, Esc/P pauses,
R retries, M mutes. F optionally requests fullscreen where supported.

The iPad layout handles desktop-style user agents, visible Safari toolbar
resizing and safe-area insets. Portrait displays a rotation message. Fullscreen
and orientation locking are not required. Actual iOS and Android hardware
testing is still required. Reloading starts a new game; checkpoints persist
within the running session. Once loaded, gameplay makes no network requests,
but offline page reload is not promised.

## Publish / update

The development files stay in the local project. From that project, run:

```
node build-portable.js
node --test tests/*.test.js
git add docs DEPLOYMENT.md
git commit -m "Update Creeper Adventure"
git push origin main
```

Configure GitHub **Settings → Pages → Deploy from a branch → main → /docs**.
Use GitHub's displayed HTTPS URL after its deployment finishes; verify that
the deployed HTML matches the local build. Only the generated site, this guide
and the ignore rules are intended for publication; development screenshots,
temporary tests, private files and credentials are excluded.
