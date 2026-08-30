# Anonymous product diagnostics

EST is local-first. The app sends no diagnostics when **Share anonymous
diagnostics** is turned off in Settings. The setting is on by default so the
project can understand which modes and features are being used; it can be
turned off at any time.

## What is sent

At most one aggregate batch per ISO week:

- app version, app build, iOS major version, and coarse device family;
- counts for launches, mode starts and completions, hints, tutorial views,
  and leaderboard views during that week;
- coarse feature flags for modes used and current feedback/display settings;
- a random batch id, a week-scoped HMAC dedupe key, and a cohort word
  (`new`, `returning`, or `reactivated`).

The install secret used to make the HMAC stays in the device-only Keychain. It
never leaves the phone, and the HMAC changes every ISO week, so it is not a
stable install id.

## What is not sent

EST never sends names, Game Center identifiers, cards, scores, exact times,
personal bests, prompts, contacts, location, or per-game/per-request events.
The app does not use advertising identifiers or App Attest for diagnostics.

Telemetry is best effort. A failed request does not affect gameplay. A failed
batch is retained locally for retry; turning diagnostics off deletes it.

The client contract is [open in the source](../EST/Models/Telemetry.swift), and
the endpoint can be overridden for development or self-hosting with the
`estTelemetryEndpoint` UserDefaults key.
