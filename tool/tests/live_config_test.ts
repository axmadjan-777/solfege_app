// Offline safety tests for the real live harness's configuration boundary.
// No credentials, environment permission, mocked network, or service calls.
import {
  ConfigError,
  type Environment,
  validateConfig,
} from "../live/config.ts";
import { junit, type LiveReport } from "../live/report.ts";

const REF = "abcdefghijklmnopqrst";
const NOW = 1_800_000_000;
const base: Environment = {
  QA_LIVE: "1",
  QA_PROJECT_REF: REF,
  QA_SUPABASE_URL: `https://${REF}.supabase.co`,
  QA_SUPABASE_PUBLISHABLE_KEY: "sb_publishable_offline_example_0123456789",
  QA_USER_A_EMAIL: "qa-a@example.invalid",
  QA_USER_A_PASSWORD: "offline-password-a",
  QA_USER_A_ID: "11111111-1111-4111-8111-111111111111",
  QA_USER_B_EMAIL: "qa-b@example.invalid",
  QA_USER_B_PASSWORD: "offline-password-b",
  QA_USER_B_ID: "22222222-2222-4222-8222-222222222222",
};

function assert(condition: unknown, message: string): asserts condition {
  if (!condition) throw new Error(message);
}

function rejected(changes: Environment) {
  try {
    validateConfig({ ...base, ...changes }, NOW);
  } catch (error) {
    assert(
      error instanceof ConfigError,
      "Invalid configuration must produce a safe configuration error",
    );
    assert(
      !error.message.includes("offline-password"),
      "Configuration errors must not expose passwords",
    );
    assert(
      !error.message.includes("sb_publishable_offline_example"),
      "Configuration errors must not expose keys",
    );
    return;
  }
  throw new Error("Unsafe or incomplete configuration was accepted");
}

function jwt(
  claims: Record<string, unknown>,
  header = { alg: "HS256", typ: "JWT" },
): string {
  const encode = (value: unknown) =>
    btoa(JSON.stringify(value)).replaceAll("+", "-").replaceAll("/", "_")
      .replaceAll("=", "");
  return `${encode(header)}.${encode(claims)}.offline_signature_0123456789`;
}
const anon = { role: "anon", ref: REF, iss: "supabase", exp: NOW + 3600 };

Deno.test("live config accepts hosted publishable and project-scoped anon client keys", () => {
  const config = validateConfig(base, NOW);
  assert(
    config.keyKind === "publishable" && config.url === base.QA_SUPABASE_URL,
    "Publishable configuration must be usable",
  );
  const legacy = validateConfig({
    ...base,
    QA_SUPABASE_PUBLISHABLE_KEY: jwt(anon),
    QA_SUPABASE_URL: `${base.QA_SUPABASE_URL}/`,
  }, NOW);
  assert(
    legacy.keyKind === "anon_jwt",
    "A real anon JWT shape must be supported",
  );
});

Deno.test("live config fails closed without opt-in or any required fixture value", () => {
  rejected({ QA_LIVE: "0" });
  for (const name of Object.keys(base) as (keyof Environment)[]) {
    rejected({ [name]: undefined });
    rejected({ [name]: "" });
  }
});

Deno.test("live config rejects privileged keys even in otherwise valid JWTs", () => {
  for (
    const key of [
      "sb_secret_offline_password_sentinel",
      "sbp_offline_management_sentinel",
      jwt({ ...anon, role: "service_role" }),
      jwt({ ...anon, role: "authenticated" }),
      jwt({ ...anon, role: "supabase_admin" }),
      jwt(anon, { alg: "none", typ: "JWT" }),
      "arbitrary-client-string",
      "sb_publishable_short",
    ]
  ) rejected({ QA_SUPABASE_PUBLISHABLE_KEY: key });
});

Deno.test("live config binds anon JWTs to the intended project and rejects expired/malformed claims", () => {
  for (
    const key of [
      jwt({ ...anon, ref: "tsrqponmlkjihgfedcba" }),
      jwt({ ...anon, exp: NOW }),
      jwt({ ...anon, exp: "2099999999" }),
      jwt({ ...anon, iss: "another-issuer" }),
      "e30.invalid-json.offline_signature_0123456789",
    ]
  ) rejected({ QA_SUPABASE_PUBLISHABLE_KEY: key });
});

Deno.test("live config rejects URL changes that could send credentials to another origin or route", () => {
  for (
    const url of [
      `http://${REF}.supabase.co`,
      "https://tsrqponmlkjihgfedcba.supabase.co",
      `https://${REF}.supabase.co.attacker.invalid`,
      `https://${REF}.supabase.co:443`,
      `https://user:password@${REF}.supabase.co`,
      `https://${REF}.supabase.co/rest/v1`,
      `https://${REF}.supabase.co?project=other`,
      `https://${REF}.supabase.co#fragment`,
      "https://localhost:54321",
    ]
  ) rejected({ QA_SUPABASE_URL: url });
  rejected({ QA_PROJECT_REF: `${REF}/other` });
});

Deno.test("live config requires two distinct explicit QA UUIDs and emails", () => {
  rejected({ QA_USER_B_ID: base.QA_USER_A_ID });
  rejected({ QA_USER_B_EMAIL: base.QA_USER_A_EMAIL!.toUpperCase() });
  rejected({ QA_USER_A_ID: "00000000-0000-0000-0000-000000000000" });
  rejected({ QA_USER_A_ID: "not-an-explicit-uuid" });
  rejected({ QA_USER_B_EMAIL: "not-an-email" });
});

Deno.test("live JUnit reports blocked acceptance as failures, never green skips", () => {
  const report: LiveReport = {
    schemaVersion: 1,
    suite: "solfege-hosted-services",
    runId: "offline-report",
    startedAt: "2026-01-01T00:00:00Z",
    finishedAt: "2026-01-01T00:00:01Z",
    mode: "live",
    status: "failed",
    exitCode: 1,
    liveAcceptance: "failed",
    limitations: [],
    checks: [
      {
        id: "auth",
        name: "Auth",
        status: "failed",
        durationMs: 1,
        detail: "HTTP 503 <unavailable> & no body",
      },
      {
        id: "profile",
        name: "Profile",
        status: "blocked",
        durationMs: 0,
        detail: "Prerequisite failed",
      },
    ],
    cleanup: [{
      id: "cleanup",
      name: "Restore",
      status: "failed",
      durationMs: 1,
      detail: "Restore could not be verified",
    }],
  };
  const xml = junit(report);
  assert(
    xml.includes('tests="3" failures="3" skipped="0"'),
    "Blocked and cleanup failures must fail CI",
  );
  assert(xml.includes('type="blocked"'), "The blocker must remain visible");
  assert(
    xml.includes("&lt;unavailable&gt; &amp; no body"),
    "JUnit diagnostics must be XML escaped",
  );
});
