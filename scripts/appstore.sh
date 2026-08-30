#!/usr/bin/env bash
# EST’s CLI-first App Store Connect workflow.
#
# Local assets:
#   ./scripts/appstore.sh prepare
#
# ASC setup after the app record exists:
#   ./scripts/appstore.sh setup <APP_ID>
#   ./scripts/appstore.sh upload-screenshots <APP_ID>
#   ./scripts/appstore.sh publish <APP_ID>
#   ./scripts/appstore.sh review-details <APP_ID>
#   ./scripts/appstore.sh submit <APP_ID>
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="${EST_VERSION:-0.1.0}"
TEAM_ID="${EST_TEAM_ID:-992N457T8D}"
BUNDLE_ID="com.centaur-labs.est"
ASC_SECRETS="${EST_ASC_SECRETS:-$HOME/.cartogram-secrets}"

load_asc_credentials() {
  if [ -f "$ASC_SECRETS" ]; then
    set -a
    source "$ASC_SECRETS"
    set +a
    export ASC_PRIVATE_KEY_PATH="${ASC_PRIVATE_KEY_PATH:-${ASC_KEY_PATH:-}}"
    export ASC_BYPASS_KEYCHAIN="${ASC_BYPASS_KEYCHAIN:-1}"
  fi
}

usage() {
  sed -n '1,26p' "$0"
  echo ""
  echo "Commands: prepare | product-page | create <APPLE_ID> | setup <APP_ID> | upload-screenshots <APP_ID> | publish <APP_ID> | review-details <APP_ID> | submit <APP_ID>"
}

product_page() {
  cd "$ROOT"
  npm run product-page --prefix appstore
}

prepare() {
  cd "$ROOT"
  xcodegen generate
  ./appstore/capture.sh light
  ./appstore/stage.sh light
  product_page
  node appstore/metadata.mjs
  node appstore/validate.mjs
  asc metadata validate --dir appstore/metadata --output table
  asc screenshots validate --path appstore/screenshots/en-US --device-type IPHONE_69 --output table
}

create_app() {
  local apple_id="$1"
  load_asc_credentials
  cd "$ROOT"
  asc web apps create \
    --apple-id "$apple_id" \
    --public-provider-id "$TEAM_ID" \
    --name "EST" \
    --bundle-id "$BUNDLE_ID" \
    --sku "EST" \
    --platform IOS \
    --primary-locale en-US \
    --version "$VERSION" \
    --output json
}

setup_app() {
  local app_id="$1"
  load_asc_credentials
  cd "$ROOT"
  asc app-setup info set \
    --app "$app_id" \
    --primary-locale en-US \
    --bundle-id "$BUNDLE_ID" \
    --content-rights DOES_NOT_USE_THIRD_PARTY_CONTENT \
    --locale en-US \
    --name "EST" \
    --subtitle "Find three. Every time." \
    --privacy-policy-url "https://github.com/michellzappa/est/blob/main/PRIVACY.md"
  asc app-setup categories set --app "$app_id" --primary GAMES --secondary PUZZLE
  asc web apps availability create \
    --app "$app_id" \
    --public-provider-id "$TEAM_ID" \
    --territory USA \
    --available-in-new-territories true
  asc app-setup pricing set \
    --app "$app_id" \
    --free \
    --base-territory USA
  asc age-rating edit --app "$app_id" --all-none

  create_leaderboard "$app_id" "Solo 81" "est.solo.completion.time"
  create_leaderboard "$app_id" "Quick 27" "est.quick.completion.time"
  echo "✓ basic EST App Store setup complete"
  echo "Next: publish a build, apply privacy declarations, then run upload-screenshots."
}

create_leaderboard() {
  local app_id="$1"
  local reference_name="$2"
  local vendor_id="$3"
  local score_range_start
  case "$vendor_id" in
    est.solo.completion.time) score_range_start=1800 ;; # 18.00 seconds
    est.quick.completion.time) score_range_start=450 ;; # 4.50 seconds
    *)
      echo "✗ Unknown EST leaderboard: $vendor_id" >&2
      return 1
      ;;
  esac

  load_asc_credentials
  if asc game-center leaderboards list --app "$app_id" --output json \
    | jq -e --arg vendor "$vendor_id" '.data[]? | select(.attributes.vendorIdentifier == $vendor)' >/dev/null; then
    echo "· Game Center leaderboard exists: $vendor_id"
    return
  fi

  # The app submits centiseconds. Do not silently create the legacy
  # ELAPSED_TIME_MILLISECOND formatter, which uses a different unit.
  if ! asc game-center leaderboards create --help 2>&1 \
    | rg -q -- 'ELAPSED_TIME_CENTISECOND'; then
    echo "✗ Installed asc does not support ELAPSED_TIME_CENTISECOND." >&2
    echo "  Upgrade asc before creating the EST Game Center leaderboards." >&2
    return 1
  fi

  asc game-center leaderboards create \
    --app "$app_id" \
    --reference-name "$reference_name" \
    --vendor-id "$vendor_id" \
    --formatter ELAPSED_TIME_CENTISECOND \
    --score-range-start "$score_range_start" \
    --score-range-end 3600000 \
    --sort ASC \
    --submission-type BEST_SCORE
}

upload_screenshots() {
  local app_id="$1"
  load_asc_credentials
  cd "$ROOT"
  product_page
  node appstore/metadata.mjs
  node appstore/validate.mjs
  asc screenshots upload \
    --app "$app_id" \
    --version "$VERSION" \
    --path appstore/screenshots \
    --device-type IPHONE_69 \
    --platform IOS \
    --replace
}

publish_app() {
  local app_id="$1"
  load_asc_credentials
  cd "$ROOT"
  node appstore/metadata.mjs
  asc publish appstore \
    --app "$app_id" \
    --project EST.xcodeproj \
    --scheme EST \
    --version "$VERSION" \
    --metadata-dir appstore/metadata \
    --clean \
    --wait \
    --archive-xcodebuild-flag "DEVELOPMENT_TEAM=$TEAM_ID"

  local version_id
  version_id="$(asc versions list --app "$app_id" --version "$VERSION" --platform IOS --output json | jq -r '.data[0].id // empty')"
  [ -n "$version_id" ] || { echo "Could not find App Store version $VERSION after publishing"; exit 1; }
  asc versions update \
    --version-id "$version_id" \
    --copyright "2026 Michell Zappa"
}

submit_app() {
  local app_id="$1"
  load_asc_credentials
  cd "$ROOT"
  asc validate --app "$app_id" --version "$VERSION" --platform IOS --output table
  local build_id
  build_id="$(asc builds info --app "$app_id" --latest --version "$VERSION" --platform IOS --output json | jq -r '.data.id // empty')"
  [ -n "$build_id" ] || { echo "No processed build found for $VERSION"; exit 1; }
  asc review submit \
    --app "$app_id" \
    --version "$VERSION" \
    --build "$build_id" \
    --confirm
}

review_details() {
  local app_id="$1"
  local first_name="${EST_REVIEW_FIRST_NAME:-Michell}"
  local last_name="${EST_REVIEW_LAST_NAME:-Zappa}"
  local contact_email="${EST_REVIEW_EMAIL:-}"
  local contact_phone="${EST_REVIEW_PHONE:-}"
  local -a contact_args=()
  [ -n "$contact_email" ] || {
    echo "Set EST_REVIEW_EMAIL to the App Review contact email before running review-details"
    exit 1
  }
  if [ -n "$contact_phone" ]; then
    contact_args+=(--contact-phone "$contact_phone")
  fi

  load_asc_credentials
  cd "$ROOT"
  local version_id
  version_id="$(asc versions list --app "$app_id" --version "$VERSION" --platform IOS --output json | jq -r '.data[0].id // empty')"
  [ -n "$version_id" ] || { echo "Could not find App Store version $VERSION"; exit 1; }

  local notes
  notes="$(<appstore/review-notes.txt)"
  local details_json
  local details_id=""
  if details_json="$(asc review details-for-version --version-id "$version_id" --output json 2>/dev/null)"; then
    details_id="$(printf '%s' "$details_json" | jq -r '.data.id // empty')"
  fi

  if [ -n "$details_id" ]; then
    asc review details-update \
      --id "$details_id" \
      --contact-first-name "$first_name" \
      --contact-last-name "$last_name" \
      --contact-email "$contact_email" \
      "${contact_args[@]}" \
      --notes "$notes"
  else
    asc review details-create \
      --version-id "$version_id" \
      --contact-first-name "$first_name" \
      --contact-last-name "$last_name" \
      --contact-email "$contact_email" \
      "${contact_args[@]}" \
      --notes "$notes"
  fi
}

command="${1:-}"
case "$command" in
  prepare) prepare ;;
  create)
    [ "$#" -eq 2 ] || { echo "usage: $0 create <APPLE_ID>"; exit 1; }
    create_app "$2"
    ;;
  product-page)
    [ "$#" -eq 1 ] || { echo "usage: $0 product-page"; exit 1; }
    product_page
    ;;
  setup|upload-screenshots|publish|review-details|submit)
    [ "$#" -eq 2 ] || { echo "usage: $0 $command <APP_ID>"; exit 1; }
    case "$command" in
      setup) setup_app "$2" ;;
      upload-screenshots) upload_screenshots "$2" ;;
      publish) publish_app "$2" ;;
      review-details) review_details "$2" ;;
      submit) submit_app "$2" ;;
    esac
    ;;
  *) usage; exit 1 ;;
esac
