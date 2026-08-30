# EST telemetry service

This is the small first-party intake for EST's optional anonymous diagnostics.
It has no accounts, client credentials, public user data, or stable install
identifiers. The Worker accepts one aggregate batch per app install per ISO
week; the week-scoped dedupe key prevents retries from inflating the same
period.

## Deploy

Install Wrangler, create the D1 database, put its id in `wrangler.toml`, then
apply the schema and deploy:

```sh
npx wrangler d1 create est-telemetry
npx wrangler d1 execute est-telemetry --remote --file=schema.sql
npx wrangler deploy
```

The client expects the deployed service at
`https://est-telemetry.envisioning.workers.dev/v1/batches`. For local testing, set
the `estTelemetryEndpoint` UserDefaults key to a loopback HTTP endpoint.

The Worker whitelists every activity and feature key, validates the app
contract, stores no request headers or IP addresses, and prunes raw batches
after 180 days. `GET /v1/community` exposes only privacy-thresholded
activity aggregates for the Settings screen: active devices, games started and
completed, sets found, and mode adoption. The testing configuration shows
values after one device reports; raise `COMMUNITY_MINIMUM_GROUP_SIZE` before a
public release if cohort privacy is required. Raw batches and version metadata
are never returned by that endpoint.
