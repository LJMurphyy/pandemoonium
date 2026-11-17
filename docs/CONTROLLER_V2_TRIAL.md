# Optional phone controller v2 (isolated trial)

This is a **side-by-side** phone-controller trial. No files used by the existing controller, Godot game, Render setup, or WebSocket relay have been modified. It is safe to review independently. Do **not** merge a copy of the old project ZIP.

## Try it

1. Start the game from your team's current Godot or itch.io build and create a room as normal.
2. Use the current phone controller at `/` for a control group, and on another phone visit `https://pandemoonium.onrender.com/controller-v2.html` **after** the PR is merged and Render redeploys.
3. Enter the same six-character room code; ready up; start a game.
4. Compare response, layouts and clarity. V2 uses exactly the same message protocol as the existing controller.

## New (experiment only)

- Joystick deadzone, clamp/diagonals, 100ms input resends, finger capture and interruption cleanup.
- Clear connecting/connected/reconnecting status, exponential retry for failed initial connections and later disconnects, role banner, roster, optional haptics, left-handed layout.
- Hides controls while host offline or browser backgrounded, and releases presses on blur and pagehide.
- Persistent reconnect token using the current server's `pandemoonium:<room>` localStorage key, so a phone can move between old and V2 controllers without changing its player identity.
- Keyboard (WASD/arrows + E/Space/Q) support for desktop testing; accessible labels/focus states and reduced-motion support.
- Tests for math, validation and state labels; does not falsely claim physical-device end-to-end coverage.

## Testing

`cd server && npm test` — the existing test runner automatically discovers `server/test/controller-v2-core.test.js`.

## Scope and team ownership

**Added only:** `server/public/controller-v2.html`, `server/public/controller-v2.css`, `server/public/controller-v2.js`, `server/public/controller-v2-core.js`, `server/test/controller-v2-core.test.js`, `docs/CONTROLLER_V2_TRIAL.md`.

**Not modified:** `server/index.js`, existing `server/public/index.html`, existing `server/public/controller.js`, existing `server/public/style.css`, `game/`, deploy configs, other test files.

## Manual tests before recommending v2 as default

- Two to four phones in same room, same and different networks.
- All ready/unready states and individual impostor privacy.
- Drag+press simultaneously; release both buttons; rotate and background Safari while moving.
- Kill/reopen Safari, check same player slot; disconnect Wi-Fi then switch to mobile data; host drop and reconnect inside 30 seconds.
- Compare responsiveness and accessibility in portrait and landscape on iOS and Android.

## Follow-up features (not part of this PR)

Order queue, recipes, meetings, voting, round reset and gameplay cues require changes to the game/server protocol. Coordinate those as separate PRs with assigned owners; no gameplay or server behavior is replaced here.
