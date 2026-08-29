# EST — agent notes

EST is a SwiftUI iPhone spinoff of the card game SET. 81 cards, four traits,
three values each. The app name shuffles its letters in-app (EST/TSE/STE/…);
the canonical product name is EST.

## Build

XcodeGen is the source of truth. Never hand-edit `EST.xcodeproj`.

```
xcodegen generate
xcodebuild -project EST.xcodeproj -scheme EST -destination 'generic/platform=iOS Simulator' build CODE_SIGNING_ALLOWED=NO
```

Run `xcodegen generate` after adding or removing a source file. A missing new
file surfaces as misleading "has no member" errors in other files, not as
"file not found".

Versioning: `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` live in
`project.yml`. Bump `CURRENT_PROJECT_VERSION` by 1 every time you hand MZ a
new build to test (then `xcodegen generate`). Settings shows the numbers.

The shared scheme is declared in `project.yml` (`scheme: testTargets: []`).
Do not remove it: without it a regenerate leaves the project scheme-less and
`xcodebuild -scheme EST` fails.

The green gate is a clean build. MZ tests by hand — do not boot simulators or
drive the UI unless asked.

## Invariants

- Card identity: `id = (count-1)*27 + tint*9 + symbol*3 + fill`. The set math
  in `Card.swift` uses trit sums mod 3; `completing(_:_:)` derives the unique
  third card. Do not duplicate set-validation logic anywhere else.
- Table rules live only in `GameEngine`: 12 cards, deal +3 while no EST is
  present, replace in place when at 12, compact when above 12.
- A match celebrates for `GameEngine.celebrationDuration` before replacements
  deal; input is blocked meanwhile and the solo clock ends at the final match
  moment, not after its celebration. `onAutoAdvance` fires after the engine
  advances on its own — the network host rebroadcasts there.
- Buttons: every control the player taps uses `GameButtonStyle` through
  `.buttonStyle(.game(role, tint:, size:))` in `ButtonStyles.swift`. Three
  rules: one `.primary` per screen, tints come from `Card.Tint` (never the
  system accent, so themes restyle the buttons with the cards), and a row is
  one size so it cannot taper or wrap. Do not use `.bordered` or
  `.borderedProminent` in game UI. Settings is a Form and keeps native rows.
- Liquid Glass: use the `glassPanel`/`glassButtonSurface` helpers in
  `GlassHelpers.swift` (iOS 26 glass, material fallback). Do not call
  `glassEffect` directly elsewhere.
- `PartySession` wraps `GameEngine` for one-device multiplayer. Solo views talk
  to `GameEngine` directly.
- Multi-device party (`NetworkPartySession`) runs over a `GKMatch` (online or
  nearby via Game Center matchmaking). The device with the lowest gamePlayerID
  is host and owns the only real `GameEngine`; clients send buzz/select events
  and render full-state JSON snapshots (`NetMessages.swift`). Times cross the
  wire as remaining seconds, never dates. Claim/lockout constants live in
  `PartySession` — the network session reuses them; do not fork them.
- `BoardGridView` and `PilesView` take plain values (with engine convenience
  initializers) so local engines and remote snapshots share the same views.
- Any player disconnect ends a network game. Real matchmaking needs the app
  record + Game Center capability live in App Store Connect; two signed-in
  devices (or device + simulator) are needed to test it.
- Game Center leaderboard IDs: `est.solo.completion.time` (full 81-card solo)
  and `est.quick.completion.time` (Quick 27). Scores are centiseconds
  (elapsed-time format, ascending). Both must be created in App Store Connect
  with exactly these IDs before submission works.
- Quick 27 is `GameEngine.Variant.quick`: the 27 solid-fill cards, 9 on the
  table. The fill trait is constant there, so the set math is untouched.
- Trait explanations come from `Card.audit(_:_:_:)`, which returns one
  `TraitVerdict` per trait. `violationDescriptions` and the tutorial's
  `TraitAuditView` both read it; do not restate the rule in a view.
- `TutorialView` is the guided tour (goal, traits, worked set, worked non-set,
  practice board, table rules). First launch shows it over the title screen,
  gated by the `hasSeenTutorial` UserDefaults key; the rules sheet replays it.
  Every card it draws is `TutorialView.cardSide`, on every step: fixed cells,
  not flexible grid columns, because a `CardView` inside a `ScrollView` has no
  reliable height to grow into, and a card that changes size between steps
  reads as a different kind of thing.
- Look settings live in `Appearance.shared` (fill style, color theme).
  `Card.Tint.color` delegates to the active theme; never hardcode card colors
  in views. The icon generator script keeps its own baked colors.
- `DEVELOPMENT_TEAM` is intentionally empty in `project.yml`. Simulator builds
  need `CODE_SIGNING_ALLOWED=NO`; device builds need MZ's team set locally.
- iPhone-only (`TARGETED_DEVICE_FAMILY: 1`), portrait. MZ decided against iPad.
- Solo rules MZ decided (2026-08-29): no mismatch penalty, auto-deal the extra
  3 cards, matchmaking open to friends + nearby + strangers. A hinted solo run
  keeps the local personal best but never submits to the leaderboard.
- Modes MZ decided: solo and 2-player duel only. The UI exposes no 3/4-player
  option; `PartySession` and the net protocol still support up to 4, so
  re-enabling is a UI + `GKMatchRequest.maxPlayers` change.

## Not built yet

- Host migration: if the host disconnects mid-match, the game ends instead of
  electing a new host.
- Sounds.
