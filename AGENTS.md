# EST — agent notes

EST is a SwiftUI iPhone/iPad spinoff of the card game SET. 81 cards, four traits,
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
`project.yml`. Before every agent validation/build, bump
`CURRENT_PROJECT_VERSION` by 1, then run `xcodegen generate`; never reuse a
build number for a new build. This applies to ordinary work-in-progress builds
as well as builds handed to MZ for testing. Keep `MARKETING_VERSION` unchanged
unless the task is a release/versioning task. Settings shows the numbers.

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
  rules: one `.primary` per screen, tints come from `GameAccent` (mapped onto
  the active card palette, never the system accent), and a row is one size so
  it cannot taper or wrap. Do not use `.bordered` or
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
  wire as remaining seconds, never dates. Claim/lockout rules live in
  `ClaimRace.Configuration`; local and network party sessions reuse them; do
  not fork them.
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
- Signing is automatic with no team hardcoded in `project.yml`, so forks can
  choose their own Apple Developer account. App Store archive scripts require
  `EST_TEAM_ID`; simulator builds still need `CODE_SIGNING_ALLOWED=NO`.
- iPhone and iPad (`TARGETED_DEVICE_FAMILY: 1,2`); iPhone remains portrait,
  while iPad supports portrait and landscape so four seats can use every edge.
  Square-ish large-screen iPhone windows use the same responsive four-seat
  layout when there is enough room.
- Solo rules MZ decided (2026-08-29): no mismatch penalty, auto-deal the extra
  3 cards, matchmaking open to friends + nearby + strangers. A hinted solo run
  keeps the local personal best but never submits to the leaderboard.
- Modes MZ decided: solo and duel. The UI exposes two-player duel on iPhone,
  and two- or four-player one-device tables on iPad; iPad matchmaking can also
  fill the existing four-player network roster.
- Never attach `.task` to a `Group` whose branches are mutually exclusive.
  SwiftUI applies the modifier to each branch. A state change that switches the
  branch destroys that view and cancels the task that set the state. This kept
  Community Pulse on "Loading…" forever. `CommunityPulseView` in
  `SettingsView.swift` now holds one `VStack` and a `Phase` enum, and the
  `.task` sits on the stable container.

## App Store Connect

The app record is `6806817604`. The App Store name is `EST - Card Trios`. The
product name stays EST. `appstore/appstore.md` is the source of truth for the
listing; edit it, then run `node appstore/metadata.mjs`.

`scripts/appstore.sh` needs `asc` 4.x. Version 3.x has no
`ELAPSED_TIME_CENTISECOND` formatter, and 4.x renamed flags the script uses.

One App Store Connect API key serves every app in the team. Reuse it. Do not
make a second key:

```
export EST_TEAM_ID=992N457T8D
export EST_ASC_SECRETS=~/.cartogram-secrets
```

Order matters in `setup`. Each rule below comes from a failed run:

- Do not pass `--bundle-id` to `asc app-setup info set`. App creation binds the
  bundle ID. Sending it again fails with "already been used".
- `PUZZLE` is a subcategory of `GAMES`, not a second category. Use
  `--primary GAMES --primary-subcategory-one GAMES_PUZZLE`.
- Create the Game Center detail before the leaderboards. A new app record has
  none, and the leaderboard call fails without one. The detail also clears the
  runtime error `GKError 15`, `5019 no game matching descriptor`.
- Use `grep`, not `rg`. `rg` is absent from some PATHs. The old `rg` check
  failed open and reported a false "asc does not support
  ELAPSED_TIME_CENTISECOND".
- Availability failure must not stop the run. It used to abort `setup` before
  the leaderboards were created.

In-app purchase product IDs accept only letters, digits, periods, and
underscores. The bundle ID `com.centaur-labs.est` has a hyphen, so the support
purchase cannot mirror it. The ID is `est.support`, matching the short scheme
of the Game Center IDs. It lives in `SupportStore.swift` and
`Config/ESTSupport.storekit`, and both must agree with App Store Connect.

Apple requires a screenshot set for every device class the app supports. EST
ships `TARGETED_DEVICE_FAMILY: 1,2`, so iPhone and iPad sets are both
mandatory. `appstore/devices.mjs` is the single source of truth for the device
classes; `appstore/validate.mjs` fails when a class has no screenshots.

These rules come from the real 1.0.0 publish. Each one failed first:

- Pass `--build-number` from `project.yml`. In local-build mode `asc publish`
  auto-resolves the build number from `--initial-build-number` (default 1) and
  ignores `CURRENT_PROJECT_VERSION`. Build 1 of 1.0.0 shipped that way, so the
  number Settings showed did not match the repo. `publish_app` now reads
  `project.yml` and passes it.
- Creating an app in the web UI makes a version named `1.0`, not `1.0.0`. The
  binary carries `CFBundleShortVersionString` from `MARKETING_VERSION`, and a
  build cannot attach to a version with a different string. Rename the version
  with `asc versions update --version-id ID --version 1.0.0`.
- Apple rejects `whatsNew` on an app that has never been released: "Attribute
  'whatsNew' cannot be edited at this time". Generate metadata with
  `EST_INITIAL_RELEASE=1` until 1.0.0 ships.
- App Review details require `contactPhone`. The script fails up front now.
- `asc review details-create` leaves `demoAccountRequired` true, which makes
  App Review expect credentials EST does not have. The script pins it false.
- App Privacy is not "Data Not Collected". Diagnostics default to on, so EST
  transmits Usage Data (product interaction), Diagnostics, and a weekly
  rotating device identifier. All are unlinked and not used for tracking. If
  the diagnostics default changes, this declaration changes with it.

Two steps need the App Store Connect web UI. The `asc` web session fails at
Apple's session-info step with status 401, and the public API rejects the
availability bootstrap:

- Creating the app record.
- Pricing and Availability. EST is free in every territory except China
  mainland. China requires a government ISBN for a game that carries an in-app
  purchase, and EST carries the support purchase.

## Not built yet

- Host migration: if the host disconnects mid-match, the game ends instead of
  electing a new host.
- Sounds.
