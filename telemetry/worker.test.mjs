import assert from "node:assert/strict";
import worker from "./worker.js";

const originalFetch = globalThis.fetch;
let emailRequest;

try {
  globalThis.fetch = async (url, options) => {
    emailRequest = { url, options };
    return new Response(JSON.stringify({ id: "test-email" }), {
      status: 200,
      headers: { "content-type": "application/json" },
    });
  };

  const response = await worker.fetch(
    new Request("https://example.test/v1/feedback", {
      method: "POST",
      headers: {
        "content-type": "application/json",
      },
      body: JSON.stringify({
        schema: 1,
        product: "est",
        message: "Please make the cards a little larger.",
        app: {
          version: "1.0.0",
          build: "103",
          ios_major: 26,
          device_family: "iphone",
        },
      }),
    }),
    {
      RESEND_API_KEY: "test-key",
      FEEDBACK_FROM_EMAIL: "feedback@example.test",
    },
  );

  assert.equal(response.status, 200);
  assert.deepEqual(await response.json(), { ok: true });
  assert.equal(emailRequest.url, "https://api.resend.com/emails");
  const email = JSON.parse(emailRequest.options.body);
  assert.deepEqual(email.to, ["mz@centaur-labs.io"]);
  assert.match(email.text, /Please make the cards a little larger\./);

  const invalidResponse = await worker.fetch(
    new Request("https://example.test/v1/feedback", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ schema: 1, product: "est", message: "" }),
    }),
    {},
  );
  assert.equal(invalidResponse.status, 400);
} finally {
  globalThis.fetch = originalFetch;
}

console.log("feedback worker tests passed");
