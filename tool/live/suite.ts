import { type LiveConfig, type QaUser } from "./config.ts";
import { type CheckResult, type EvaluationArtifact } from "./report.ts";

const REQUEST_TIMEOUT_MS = 15_000;
const GEMINI_TIMEOUT_MS = 60_000;
const MAX_RESPONSE_BYTES = 131_072;
const PROFILE_COLUMNS = [
  "id",
  "display_name",
  "age",
  "musician_level",
  "onboarding_completed",
  "preferred_note_language",
  "gender",
  "created_at",
  "updated_at",
] as const;
const QUESTION =
  "Назови три ноты тонического трезвучия До мажор по-русски и качество аккорда. Ответь кратко, одним предложением.";

type Label = QaUser["label"];
type JsonObject = Record<string, unknown>;
interface HttpResult {
  status: number;
  body: unknown;
  isJson: boolean;
  contentType: string;
}
interface Session {
  accessToken: string;
  refreshToken: string;
}
interface Profile extends JsonObject {
  id: string;
  display_name: string | null;
}

class LiveFailure extends Error {}

function assert(condition: unknown, message: string): asserts condition {
  if (!condition) throw new LiveFailure(message);
}

function object(value: unknown): JsonObject | undefined {
  return typeof value === "object" && value !== null && !Array.isArray(value)
    ? value as JsonObject
    : undefined;
}

function safeFailure(error: unknown): string {
  // Fetch/JSON/runtime errors may include a URL, body or credentials. Never log them.
  return error instanceof LiveFailure
    ? error.message
    : "Unexpected failure; sensitive error details withheld.";
}

function httpFailure(result: HttpResult, label: string): string {
  return `${label}: unexpected HTTP ${result.status}; response body withheld.`;
}

function sameProfile(actual: Profile, expected: Profile): boolean {
  // set_updated_at advances the audit timestamp on every accepted update.
  return PROFILE_COLUMNS.filter((key) => key !== "updated_at").every((key) =>
    actual[key] === expected[key]
  );
}

export interface SuiteResult {
  checks: CheckResult[];
  cleanup: CheckResult[];
  evaluation?: EvaluationArtifact;
}

class HostedSuite {
  readonly checks: CheckResult[] = [];
  readonly cleanup: CheckResult[] = [];
  evaluation?: EvaluationArtifact;
  private sessions = new Map<Label, Session>();
  private snapshots = new Map<Label, Profile>();
  private credentials: string[];
  private marker: string;

  constructor(private config: LiveConfig, private runId: string) {
    this.credentials = [
      config.key,
      ...config.users.flatMap((u) => [u.email, u.password, u.id]),
    ];
    this.marker = `solfege-live-${runId}`;
  }

  private async request(
    path: string,
    label: string,
    init: RequestInit = {},
    timeoutMs = REQUEST_TIMEOUT_MS,
  ): Promise<HttpResult> {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), timeoutMs);
    try {
      const response = await fetch(`${this.config.url}${path}`, {
        ...init,
        redirect: "error",
        cache: "no-store",
        signal: controller.signal,
      });
      const chunks: Uint8Array[] = [];
      let length = 0;
      const reader = response.body?.getReader();
      if (reader) {
        for (;;) {
          const next = await reader.read();
          if (next.done) break;
          length += next.value.length;
          if (length > MAX_RESPONSE_BYTES) {
            controller.abort();
            throw new LiveFailure(
              `${label}: response exceeded the safe size limit; body withheld.`,
            );
          }
          chunks.push(next.value);
        }
      }
      const bytes = new Uint8Array(length);
      let offset = 0;
      for (const chunk of chunks) {
        bytes.set(chunk, offset);
        offset += chunk.length;
      }
      let body: unknown;
      let isJson = false;
      try {
        body = JSON.parse(new TextDecoder().decode(bytes));
        isJson = true;
      } catch {
        // Non-JSON bodies are never retained or printed.
      }
      return {
        status: response.status,
        body,
        isJson,
        contentType: response.headers.get("content-type") ?? "",
      };
    } catch (error) {
      if (error instanceof LiveFailure) throw error;
      const kind = error instanceof Error ? error.name : "unknown";
      throw new LiveFailure(
        `${label}: transport ${kind}; aborted=${controller.signal.aborted} (${timeoutMs} ms cap); sensitive details withheld.`,
      );
    } finally {
      clearTimeout(timer);
    }
  }

  private headers(user?: QaUser, anonymousRest = false): Headers {
    const headers = new Headers({
      apikey: this.config.key,
      "Content-Type": "application/json",
      "Cache-Control": "no-store",
    });
    if (user) {
      const session = this.sessions.get(user.label);
      assert(session, `Verified QA user ${user.label} session is required.`);
      headers.set("Authorization", `Bearer ${session.accessToken}`);
    } else if (anonymousRest && this.config.keyKind === "anon_jwt") {
      headers.set("Authorization", `Bearer ${this.config.key}`);
    }
    return headers;
  }

  private async check(
    id: string,
    name: string,
    dependencies: string[],
    action: () => Promise<void>,
  ): Promise<void> {
    const blocked = dependencies.filter((dependency) =>
      !this.checks.some((result) =>
        result.id === dependency && result.status === "passed"
      )
    );
    if (blocked.length > 0) {
      this.checks.push({
        id,
        name,
        status: "blocked",
        durationMs: 0,
        detail: `Prerequisite checks failed: ${
          blocked.join(", ")
        }. Live acceptance is incomplete.`,
      });
      console.log(`BLOCKED ${id}`);
      return;
    }
    const start = performance.now();
    try {
      await action();
      this.checks.push({
        id,
        name,
        status: "passed",
        durationMs: Math.round(performance.now() - start),
        detail: "Verified against the hosted service.",
      });
      console.log(`PASS ${id}`);
    } catch (error) {
      const detail = safeFailure(error);
      this.checks.push({
        id,
        name,
        status: "failed",
        durationMs: Math.round(performance.now() - start),
        detail,
      });
      console.error(`FAIL ${id}: ${detail}`);
    }
  }

  private async validateIdentity(
    user: QaUser,
    session: Session,
  ): Promise<void> {
    this.credentials.push(session.accessToken, session.refreshToken);
    const result = await this.request(
      "/auth/v1/user",
      `QA user ${user.label} identity`,
      {
        headers: new Headers({
          apikey: this.config.key,
          Authorization: `Bearer ${session.accessToken}`,
        }),
      },
    );
    assert(
      result.status === 200,
      httpFailure(result, `QA user ${user.label} identity`),
    );
    const identity = object(result.body);
    assert(
      identity?.id === user.id,
      `Authenticated QA user ${user.label} UUID does not match its explicitly authorized UUID. Profile writes are blocked.`,
    );
    assert(
      typeof identity?.email === "string" &&
        identity.email.toLowerCase() === user.email.toLowerCase(),
      `Authenticated QA user ${user.label} email does not match its configuration.`,
    );
    this.sessions.set(user.label, session);
  }

  private async authenticate(user: QaUser, refresh = false): Promise<void> {
    const existing = this.sessions.get(user.label);
    assert(
      !refresh || existing,
      `QA user ${user.label} must sign in before refresh.`,
    );
    const label = `QA user ${user.label} ${
      refresh ? "refresh" : "password sign-in"
    }`;
    const result = await this.request(
      `/auth/v1/token?grant_type=${refresh ? "refresh_token" : "password"}`,
      label,
      {
        method: "POST",
        headers: this.headers(),
        body: JSON.stringify(
          refresh
            ? { refresh_token: existing!.refreshToken }
            : { email: user.email, password: user.password },
        ),
      },
    );
    assert(result.status === 200, httpFailure(result, label));
    const data = object(result.body);
    assert(
      typeof data?.access_token === "string" && data.access_token.length > 20,
      `${label}: missing access token.`,
    );
    assert(
      typeof data.refresh_token === "string" && data.refresh_token.length > 10,
      `${label}: missing refresh token.`,
    );
    // Register secrets before inspecting any remaining response fields.
    this.credentials.push(data.access_token, data.refresh_token);
    assert(
      object(data.user)?.id === user.id,
      `${label}: auth UUID does not match the explicitly authorized QA account. Profile writes are blocked.`,
    );
    await this.validateIdentity(user, {
      accessToken: data.access_token,
      refreshToken: data.refresh_token,
    });
  }

  private profilePath(user: QaUser): string {
    // There is deliberately no unfiltered profiles endpoint in this suite.
    return `/rest/v1/profiles?${new URLSearchParams({
      id: `eq.${user.id}`,
      select: PROFILE_COLUMNS.join(","),
    })}`;
  }

  private async readProfile(user: QaUser): Promise<Profile> {
    const result = await this.request(
      this.profilePath(user),
      `QA user ${user.label} own profile read`,
      { headers: this.headers(user) },
    );
    assert(
      result.status === 200,
      httpFailure(result, `QA user ${user.label} own profile read`),
    );
    assert(
      Array.isArray(result.body) && result.body.length === 1,
      `QA user ${user.label} must have exactly one existing profile at its authorized UUID; no row will be created by this suite.`,
    );
    const profile = object(result.body[0]);
    assert(
      profile?.id === user.id,
      `QA user ${user.label} profile UUID mismatch.`,
    );
    assert(
      profile.display_name === null || typeof profile.display_name === "string",
      `QA user ${user.label} profile display_name contract is invalid.`,
    );
    assert(
      PROFILE_COLUMNS.every((column) => Object.hasOwn(profile, column)),
      `QA user ${user.label} profile schema is incomplete.`,
    );
    return profile as Profile;
  }

  private async patchName(
    owner: QaUser,
    displayName: unknown,
    actor: QaUser | undefined,
  ): Promise<HttpResult> {
    // Both owner IDs were validated against Auth before any profile write.
    assert(
      this.sessions.size === 2 && this.snapshots.size === 2 &&
        this.config.users[0].id !== this.config.users[1].id,
      "Both distinct QA identities and baseline profiles must be verified before a profile write.",
    );
    const headers = this.headers(actor, !actor);
    headers.set("Prefer", "return=representation");
    return await this.request(
      this.profilePath(owner),
      `QA user ${owner.label} profile patch`,
      {
        method: "PATCH",
        headers,
        body: JSON.stringify({ display_name: displayName }),
      },
    );
  }

  private async restore(owner: QaUser): Promise<void> {
    const baseline = this.snapshots.get(owner.label);
    assert(
      baseline,
      `QA user ${owner.label} baseline is required for restore.`,
    );
    let actual = await this.readProfile(owner);
    if (actual.display_name !== baseline.display_name) {
      const result = await this.patchName(owner, baseline.display_name, owner);
      assert(
        result.status === 200 && Array.isArray(result.body) &&
          result.body.length === 1,
        `QA user ${owner.label} profile restore failed (HTTP ${result.status}); details withheld.`,
      );
      actual = await this.readProfile(owner);
    }
    assert(
      sameProfile(actual, baseline),
      `QA user ${owner.label} profile data differs from the original baseline after restore; audit updated_at is excluded.`,
    );
  }

  private async roundTrip(owner: QaUser): Promise<void> {
    try {
      const marker = `${this.marker}-${owner.label}`;
      const result = await this.patchName(owner, marker, owner);
      assert(
        result.status === 200,
        httpFailure(result, `QA user ${owner.label} own profile patch`),
      );
      assert(
        Array.isArray(result.body) && result.body.length === 1 &&
          object(result.body[0])?.id === owner.id,
        `QA user ${owner.label} own profile patch must return exactly its own row.`,
      );
      const actual = await this.readProfile(owner);
      assert(
        actual.display_name === marker,
        `QA user ${owner.label} own profile update was not persisted.`,
      );
    } finally {
      await this.restore(owner);
    }
  }

  private async denial(
    owner: QaUser,
    actor: QaUser | undefined,
    operation: "read" | "patch" | "insert",
  ): Promise<void> {
    try {
      await this.probeDenial(owner, actor, operation);
    } finally {
      // A denied-write assertion or network timeout can follow a real mutation.
      // Restore through the owner immediately, and retry in the suite's finally.
      if (operation !== "read") await this.restore(owner);
    }
  }

  private async probeDenial(
    owner: QaUser,
    actor: QaUser | undefined,
    operation: "read" | "patch" | "insert",
  ): Promise<void> {
    let result: HttpResult;
    if (operation === "patch") {
      result = await this.patchName(owner, `${this.marker}-forbidden`, actor);
    } else {
      const headers = this.headers(actor, !actor);
      headers.set("Prefer", "return=representation");
      if (operation === "insert") {
        assert(
          this.sessions.size === 2 && this.snapshots.size === 2,
          "Both QA identities and profiles are required before an insert denial probe.",
        );
      }
      result = await this.request(
        this.profilePath(owner),
        `Profile ${operation} denial probe`,
        {
          method: operation === "read" ? "GET" : "POST",
          headers,
          ...(operation === "insert"
            ? {
              body: JSON.stringify({
                id: owner.id,
                display_name: `${this.marker}-forbidden`,
              }),
            }
            : {}),
        },
      );
    }
    const databaseDenied = (result.status === 401 || result.status === 403) &&
      object(result.body)?.code === "42501";
    const hiddenRows = operation !== "insert" && result.status === 200 &&
      Array.isArray(result.body) && result.body.length === 0;
    assert(
      databaseDenied || hiddenRows,
      `Profile ${operation} denial was not established (HTTP ${result.status}); only an empty scoped result or database access denial counts. Duplicate-key errors do not prove RLS.`,
    );
    const baseline = this.snapshots.get(owner.label)!;
    assert(
      sameProfile(await this.readProfile(owner), baseline),
      `Unauthorized ${operation} changed the QA user ${owner.label} profile.`,
    );
  }

  private redact(value: string): { text: string; changed: boolean } {
    let text = value;
    for (
      const secret of [...new Set(this.credentials)].sort((a, b) =>
        b.length - a.length
      )
    ) {
      if (secret) text = text.replaceAll(secret, "[REDACTED]");
    }
    text = text.replace(
      /\b(?:sb_(?:secret|publishable)_[A-Za-z0-9_-]+|sbp_[A-Za-z0-9_-]+|eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+|AIza[A-Za-z0-9_-]{30,})\b/g,
      "[REDACTED]",
    );
    text = text.replace(
      /[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}/g,
      "[REDACTED]",
    );
    return { text, changed: text !== value };
  }

  private async gemini(owner: QaUser): Promise<void> {
    const requestedAt = new Date().toISOString();
    // Exactly one paid model request, with no retry or fabricated fallback.
    const result = await this.request(
      "/functions/v1/gemini-chat",
      "Deployed Gemini request",
      {
        method: "POST",
        headers: this.headers(owner),
        body: JSON.stringify({ messages: [{ role: "user", text: QUESTION }] }),
      },
      GEMINI_TIMEOUT_MS,
    );
    assert(
      result.status === 200,
      httpFailure(result, "Deployed Gemini request"),
    );
    const data = object(result.body);
    const answer = typeof data?.answer === "string"
      ? this.redact(data.answer)
      : undefined;
    const question = this.redact(QUESTION);
    const model = typeof data?.model === "string"
      ? this.redact(data.model)
      : undefined;
    const validModel = model && !model.changed &&
      /^gemini-[A-Za-z0-9._-]{1,100}$/.test(model.text);
    const musical = answer &&
      /трезвуч|мажор|интервал|аккорд|нота|ноты/iu.test(answer.text);
    const notes = answer &&
      ["до", "ми", "соль"].every((note) =>
        new RegExp(`(?:^|[^\\p{L}])${note}(?=$|[^\\p{L}])`, "iu").test(
          answer.text,
        )
      );
    const valid = result.isJson &&
      result.contentType.toLowerCase().includes("application/json") &&
      data && !Object.hasOwn(data, "error") && answer && !answer.changed &&
      !question.changed &&
      answer.text.trim().length >= 20 && answer.text.length <= 64_000 &&
      validModel && musical && notes;
    if (answer) {
      this.evaluation = {
        schemaVersion: 1,
        runId: this.runId,
        source: "deployed_supabase_edge_function",
        function: "gemini-chat",
        requestedAt,
        question: question.text,
        answer: answer.text,
        model: validModel ? model!.text : "[invalid model field]",
        credentialsRedacted: answer.changed || question.changed ||
          Boolean(model?.changed),
        automatedContract: valid ? "passed" : "failed",
        semanticEvaluation: "pending_separate_review",
      };
    }
    assert(
      valid,
      "Deployed Gemini response failed the JSON {answer, model}, nonempty musical answer, or credential-safety contract; inspect the redacted evaluation artifact if available. Model quality requires separate semantic review.",
    );
  }

  async run(): Promise<SuiteResult> {
    const [a, b] = this.config.users;
    const identities = ["auth.sign_in.A", "auth.sign_in.B"];
    const ready = [
      ...identities,
      "auth.refresh.A",
      "auth.refresh.B",
      "profile.read.A",
      "profile.read.B",
    ];
    try {
      for (const user of this.config.users) {
        await this.check(
          `auth.sign_in.${user.label}`,
          `Password sign-in and verified QA ${user.label} identity`,
          [],
          () => this.authenticate(user),
        );
      }
      for (const user of this.config.users) {
        await this.check(
          `auth.refresh.${user.label}`,
          `Refresh and verified QA ${user.label} identity`,
          [`auth.sign_in.${user.label}`],
          () => this.authenticate(user, true),
        );
      }
      for (const user of this.config.users) {
        await this.check(
          `profile.read.${user.label}`,
          `Read own QA ${user.label} profile baseline`,
          [...identities, `auth.refresh.${user.label}`],
          async () => {
            this.snapshots.set(user.label, await this.readProfile(user));
          },
        );
      }
      for (const user of this.config.users) {
        await this.check(
          `profile.round_trip.${user.label}`,
          `Update, read, and restore own QA ${user.label} profile`,
          ready,
          () => this.roundTrip(user),
        );
      }
      for (const operation of ["read", "patch", "insert"] as const) {
        await this.check(
          `rls.anonymous.${operation}`,
          `Anonymous profile ${operation} is denied`,
          ready,
          () => this.denial(a, undefined, operation),
        );
      }
      for (const operation of ["read", "patch", "insert"] as const) {
        await this.check(
          `rls.A_to_B.${operation}`,
          `QA A cannot ${operation} QA B profile`,
          ready,
          () => this.denial(b, a, operation),
        );
      }
      await this.check(
        "edge.unauthenticated",
        "Deployed Edge Function denies missing user bearer token",
        [],
        async () => {
          const result = await this.request(
            "/functions/v1/gemini-chat",
            "Unauthenticated deployed Edge request",
            {
              method: "POST",
              headers: this.headers(),
              body: JSON.stringify({
                messages: [{ role: "user", text: QUESTION }],
              }),
            },
          );
          assert(
            (result.status === 401 || result.status === 403) &&
              !object(result.body)?.answer,
            `Deployed Edge Function did not deny an unauthenticated request (HTTP ${result.status}); body withheld.`,
          );
        },
      );
      await this.check(
        "edge.gemini",
        "One real musical Gemini answer through deployed Edge Function",
        [...identities, "auth.refresh.A", "edge.unauthenticated"],
        () => this.gemini(a),
      );
    } finally {
      for (const user of this.config.users) {
        if (!this.snapshots.has(user.label)) continue;
        const start = performance.now();
        try {
          await this.restore(user);
          this.cleanup.push({
            id: `cleanup.profile.${user.label}`,
            name: `Verify restored QA ${user.label} profile`,
            status: "passed",
            durationMs: Math.round(performance.now() - start),
            detail:
              "Original profile data restored and verified; trigger-managed updated_at may advance.",
          });
        } catch (error) {
          const detail = `QA user ${user.label} restore/verification failed: ${
            safeFailure(error)
          }`;
          this.cleanup.push({
            id: `cleanup.profile.${user.label}`,
            name: `Verify restored QA ${user.label} profile`,
            status: "failed",
            durationMs: Math.round(performance.now() - start),
            detail,
          });
          console.error(`FAIL cleanup.profile.${user.label}: ${detail}`);
        }
      }
    }
    return {
      checks: this.checks,
      cleanup: this.cleanup,
      evaluation: this.evaluation,
    };
  }
}

export async function runSuite(
  config: LiveConfig,
  runId: string,
): Promise<SuiteResult> {
  return await new HostedSuite(config, runId).run();
}
