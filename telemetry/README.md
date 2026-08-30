# EST telemetry service

This is the small first-party intake for EST's optional anonymous diagnostics.
It also forwards the app's optional free-text feedback form to
`mz@centaur-labs.io`. Feedback is not stored in D1 and does not require
anonymous-diagnostics consent.

The diagnostics side has no accounts, client credentials, public user data, or
stable install identifiers. The Worker stores one aggregate row per app install
per ISO week; the week-scoped dedupe key makes retries and activity refreshes
update that row instead of inflating the period.

## Deploy

Install Wrangler, create the D1 database, put its id in `wrangler.toml`, then
apply the schema and deploy:

```sh
npx wrangler d1 create est-telemetry
npx wrangler d1 execute est-telemetry --remote --file=schema.sql
npx wrangler deploy
```

For feedback delivery, configure the verified Resend sender before deploying:

```sh
npx wrangler secret put RESEND_API_KEY
npx wrangler secret put FEEDBACK_FROM_EMAIL
```

The first-party EST target uses
`https://est-telemetry.envisioning.workers.dev/v1/batches`. A distributor can
replace the `ESTTelemetryEndpoint` Info.plist build setting with
`https://your-worker.example/v1/batches`, or set the `estTelemetryEndpoint`
UserDefaults key during local testing. Forks should keep diagnostics disabled
unless they have reviewed and configured their own service.

The Worker whitelists every activity and feature key, validates the app
contract, stores no request headers or IP addresses, and prunes raw batches
after 180 days. `GET /v1/community` exposes only privacy-thresholded
activity aggregates for the Settings screen: active devices, games started and
completed, sets found, and mode adoption. The testing configuration shows
values after one device reports during testing. Raise
`COMMUNITY_MINIMUM_GROUP_SIZE` before a public release if cohort privacy is
required. Raw batches and version metadata are never returned by that endpoint.
Because the intake is intentionally
unauthenticated, configure Cloudflare rate limiting or WAF rules before public
deployment and treat the aggregate as approximate.

## Feedback

The app posts JSON to `POST /v1/feedback`. The Worker validates and length-caps
the message, adds the app version/build and coarse device context supplied by
the app, and forwards it through Resend. Set `RESEND_API_KEY` and
`FEEDBACK_FROM_EMAIL` as Worker secrets/variables; the recipient is fixed in
`worker.js`.

The endpoint is intentionally simple and unauthenticated because the app
cannot keep a secret. Before public deployment, configure a Cloudflare rate
limit for `POST /v1/feedback` (for example, a small per-IP hourly limit) and
ensure the Resend sender is a verified domain. Feedback may be retained by the
recipient's email system and Resend; the Worker does not write it to D1.
