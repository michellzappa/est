const ALLOWED_ACTIVITY = new Set([
  "launches",
  "full_solo_started", "full_solo_completed",
  "quick_solo_started", "quick_solo_completed",
  "local_duel_started", "local_duel_completed",
  "network_duel_started", "network_duel_completed",
  "hints_used", "tutorial_viewed", "leaderboard_viewed",
]);

const ALLOWED_FEATURES = new Set([
  "tutorial_seen",
  "quick_solo_used", "local_duel_used", "network_duel_used",
  "hints_used", "sound_effects_enabled", "haptics_enabled",
  "immersive_game_mode",
]);

const ALLOWED_COHORTS = new Set(["new", "returning", "reactivated"]);
const ALLOWED_DEVICE_FAMILIES = new Set(["iphone", "ipad"]);
const RETENTION_DAYS = 180;

function json(body, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "content-type": "application/json; charset=utf-8",
      "cache-control": "no-store",
    },
  });
}

function boundedString(value, max) {
  return typeof value === "string" && value.length > 0 && value.length <= max
    ? value
    : null;
}

function safeActivity(value) {
  if (!value || typeof value !== "object" || Array.isArray(value)) return {};
  const result = {};
  for (const [key, count] of Object.entries(value)) {
    if (ALLOWED_ACTIVITY.has(key)
        && Number.isInteger(count) && count >= 0 && count <= 999999) {
      result[key] = count;
    }
  }
  return result;
}

function safeFeatures(value) {
  if (!value || typeof value !== "object" || Array.isArray(value)) return {};
  const result = {};
  for (const [key, enabled] of Object.entries(value)) {
    if (ALLOWED_FEATURES.has(key) && typeof enabled === "boolean") {
      result[key] = enabled;
    }
  }
  return result;
}

function sanitize(payload) {
  if (!payload || typeof payload !== "object") return null;
  if (payload.schema !== 1 || payload.product !== "est") return null;

  const batchID = boundedString(payload.batch_id, 80);
  const period = boundedString(payload.period, 12);
  const dedupeKey = typeof payload.dedupe_key === "string"
      && /^[0-9a-f]{64}$/.test(payload.dedupe_key)
    ? payload.dedupe_key
    : null;
  const cohort = typeof payload.cohort === "string"
      && ALLOWED_COHORTS.has(payload.cohort)
    ? payload.cohort
    : null;
  const app = payload.app;

  if (!batchID || !period || !dedupeKey
      || !/^\d{4}-W(?:0[1-9]|[1-4]\d|5[0-3])$/.test(period)
      || !app || typeof app !== "object") {
    return null;
  }

  const version = boundedString(app.version, 32);
  const build = boundedString(app.build, 64);
  const iosMajor = Number.isInteger(app.ios_major)
      && app.ios_major >= 13 && app.ios_major <= 99
    ? app.ios_major
    : null;
  const deviceFamily = ALLOWED_DEVICE_FAMILIES.has(app.device_family)
    ? app.device_family
    : null;
  if (!version || !build || iosMajor === null || !deviceFamily) return null;

  const safe = {
    schema: 1,
    product: "est",
    batch_id: batchID,
    dedupe_key: dedupeKey,
    period,
    cohort,
    app: {
      version,
      build,
      ios_major: iosMajor,
      device_family: deviceFamily,
    },
    activity: safeActivity(payload.activity),
    features: safeFeatures(payload.features),
  };
  return JSON.stringify(safe).length <= 16384 ? safe : null;
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    if (request.method === "GET" && url.pathname === "/health") {
      return json({ ok: true });
    }
    if (request.method !== "POST" || url.pathname !== "/v1/batches") {
      return json({ error: "method_not_allowed" }, 405);
    }
    if (!request.headers.get("content-type")?.toLowerCase()
        .startsWith("application/json")) {
      return json({ error: "content_type_required" }, 415);
    }

    let payload;
    try {
      payload = await request.json();
    } catch {
      return json({ error: "invalid_json" }, 400);
    }
    const safe = sanitize(payload);
    if (!safe) return json({ error: "invalid_payload" }, 400);

    const receivedAt = new Date().toISOString();
    await env.DB.prepare(
      `INSERT OR IGNORE INTO telemetry_batches
       (batch_id, received_at, period, dedupe_key, cohort, app_version,
        app_build, ios_major, device_family, payload)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`
    ).bind(
      safe.batch_id,
      receivedAt,
      safe.period,
      safe.dedupe_key,
      safe.cohort,
      safe.app.version,
      safe.app.build,
      safe.app.ios_major,
      safe.app.device_family,
      JSON.stringify(safe),
    ).run();
    return json({ ok: true });
  },

  async scheduled(_event, env) {
    await env.DB.prepare(
      "DELETE FROM telemetry_batches WHERE received_at < datetime('now', ?)"
    ).bind(`-${RETENTION_DAYS} days`).run();
  },
};
