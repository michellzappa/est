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

The green gate is a clean build. MZ tests by hand — do not boot simulators or
drive the UI unless asked.

## Invariants

- Card identity: `id = (count-1)*27 + tint*9 + symbol*3 + fill`. The set math
  in `Card.swift` uses trit sums mod 3; `completing(_:_:)` derives the unique
  third card. Do not duplicate set-validation logic anywhere else.
- Table rules live only in `GameEngine`: 12 cards, deal +3 while no EST is
  present, replace in place when at 12, compact when above 12.
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
- Game Center leaderboard ID: `est.solo.completion.time`. Scores are
  centiseconds (elapsed-time format, ascending). The leaderboard must be
  created in App Store Connect with exactly this ID before submission works.
- `DEVELOPMENT_TEAM` is intentionally empty in `project.yml`. Simulator builds
  need `CODE_SIGNING_ALLOWED=NO`; device builds need MZ's team set locally.
- iPhone-only (`TARGETED_DEVICE_FAMILY: 1`), portrait. MZ decided against iPad.
- Solo rules MZ decided (2026-08-29): no mismatch penalty, auto-deal the extra
  3 cards, matchmaking open to friends + nearby + strangers. A hinted solo run
  keeps the local personal best but never submits to the leaderboard.

## Not built yet

- Host migration: if the host disconnects mid-match, the game ends instead of
  electing a new host.
- Sounds.
