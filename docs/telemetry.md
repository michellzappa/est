# Anonymous product diagnostics

EST is local-first. **Share anonymous diagnostics** is enabled by default for
new installs and can be disabled in Settings. Existing installs keep their
current choice. The first-party target uses its dedicated EST Worker; forks
can replace the endpoint or leave diagnostics disabled. Disabling diagnostics
also hides the in-app Community Pulse aggregate stats.

## What is sent

One aggregate record per ISO week, refreshed after a completed game when
needed:

- app version, app build, iOS major version, and coarse device family;
- counts for launches, games started and completed, sets found, mode starts
  and completions, hints, tutorial views, and leaderboard views during that
  week;
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

The client contract is [open in the source](../EST/Models/Telemetry.swift).
For development or self-hosting, set the `ESTTelemetryEndpoint` Info.plist
build setting or override the `estTelemetryEndpoint` UserDefaults key.

## Community Pulse

The app's Settings screen can read a public aggregate from the same service.
It shows recent active-device counts, games started and completed, sets found,
and mode adoption. During testing, values are visible once one device reports
for the period. It does not expose app versions, builds, device families,
cohorts, or raw batches, so a separate web page is not required for the in-app
view. The endpoint is intentionally unauthenticated because the client cannot
keep a secret; operators should add Cloudflare rate limiting/WAF rules before
using the service publicly and treat the aggregates as approximate.

## In-app feedback

The separate `POST /v1/feedback` route accepts the text from Settings > Send
feedback. It is not part of anonymous diagnostics and is available regardless
of the diagnostics toggle. The Worker validates it and forwards it to
`mz@centaur-labs.io`; it does not store the message in D1. The message includes
the app version, build, iOS major version, and coarse device family. See
[`telemetry/README.md`](../telemetry/README.md) for the Worker configuration
and rate-limiting requirement.
