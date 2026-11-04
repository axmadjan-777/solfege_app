// Pure validation: importing this module never reads environment or uses network.
export const ENV_NAMES = [
  "QA_LIVE",
  "QA_PROJECT_REF",
  "QA_SUPABASE_URL",
  "QA_SUPABASE_PUBLISHABLE_KEY",
  "QA_USER_A_EMAIL",
  "QA_USER_A_PASSWORD",
  "QA_USER_A_ID",
  "QA_USER_B_EMAIL",
  "QA_USER_B_PASSWORD",
  "QA_USER_B_ID",
] as const;

export type Environment = Partial<Record<(typeof ENV_NAMES)[number], string>>;

export interface QaUser {
  label: "A" | "B";
  email: string;
  password: string;
  id: string;
}

export interface LiveConfig {
  projectRef: string;
  url: string;
  key: string;
  keyKind: "publishable" | "anon_jwt";
  users: readonly [QaUser, QaUser];
}

export class ConfigError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "ConfigError";
  }
}

function requireValue(
  env: Environment,
  name: (typeof ENV_NAMES)[number],
): string {
  const value = env[name];
  if (typeof value !== "string" || value.length === 0) {
    throw new ConfigError(`Required configuration is missing: ${name}.`);
  }
  return value;
}

function decodeObject(segment: string): Record<string, unknown> {
  try {
    const padded = segment.replaceAll("-", "+").replaceAll("_", "/");
    const value = JSON.parse(
      atob(padded.padEnd(Math.ceil(padded.length / 4) * 4, "=")),
    );
    if (typeof value !== "object" || value === null || Array.isArray(value)) {
      throw new Error();
    }
    return value;
  } catch {
    throw new ConfigError(
      "QA_SUPABASE_PUBLISHABLE_KEY is not a valid client key.",
    );
  }
}

function validateKey(
  key: string,
  ref: string,
  nowSeconds: number,
): LiveConfig["keyKind"] {
  if (/^sb_publishable_[A-Za-z0-9_-]{16,}$/.test(key)) return "publishable";
  if (!/^[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]{16,}$/.test(key)) {
    throw new ConfigError(
      "QA_SUPABASE_PUBLISHABLE_KEY must be a publishable key or anon JWT; secret/management keys are forbidden.",
    );
  }
  const [headerSegment, payloadSegment] = key.split(".");
  const header = decodeObject(headerSegment);
  const claims = decodeObject(payloadSegment);
  if (
    header.alg !== "HS256" || claims.role !== "anon" || claims.ref !== ref ||
    claims.iss !== "supabase" || typeof claims.exp !== "number" ||
    !Number.isFinite(claims.exp) || claims.exp <= nowSeconds
  ) {
    throw new ConfigError(
      "The anon JWT must be unexpired, belong to QA_PROJECT_REF, and have role=anon; privileged tokens are forbidden.",
    );
  }
  return "anon_jwt";
}

export function validateConfig(
  env: Environment,
  nowSeconds = Date.now() / 1000,
): LiveConfig {
  if (requireValue(env, "QA_LIVE") !== "1") {
    throw new ConfigError("Explicit live opt-in is required: QA_LIVE=1.");
  }
  const projectRef = requireValue(env, "QA_PROJECT_REF");
  if (!/^[a-z0-9]{20}$/.test(projectRef)) {
    throw new ConfigError(
      "QA_PROJECT_REF must be a hosted Supabase project reference.",
    );
  }
  const url = `https://${projectRef}.supabase.co`;
  const suppliedUrl = requireValue(env, "QA_SUPABASE_URL");
  if (suppliedUrl !== url && suppliedUrl !== `${url}/`) {
    throw new ConfigError(
      "QA_SUPABASE_URL must exactly match the HTTPS hosted project in QA_PROJECT_REF, with no credentials, port, path, query, or fragment.",
    );
  }
  const key = requireValue(env, "QA_SUPABASE_PUBLISHABLE_KEY");
  const keyKind = validateKey(key, projectRef, nowSeconds);
  const users = (["A", "B"] as const).map((label): QaUser => {
    const email = requireValue(env, `QA_USER_${label}_EMAIL`);
    const password = requireValue(env, `QA_USER_${label}_PASSWORD`);
    const id = requireValue(env, `QA_USER_${label}_ID`).toLowerCase();
    if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) {
      throw new ConfigError(
        `QA_USER_${label}_EMAIL must be a valid email address.`,
      );
    }
    if (
      !/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/.test(
        id,
      ) || /^0{8}-0{4}-0{4}-0{4}-0{12}$/.test(id)
    ) {
      throw new ConfigError(
        `QA_USER_${label}_ID must be the explicitly authorized QA account UUID.`,
      );
    }
    return { label, email, password, id };
  }) as [QaUser, QaUser];
  if (
    users[0].id === users[1].id ||
    users[0].email.toLowerCase() === users[1].email.toLowerCase()
  ) {
    throw new ConfigError(
      "QA users A and B must have different UUIDs and email addresses.",
    );
  }
  return { projectRef, url, key, keyKind, users };
}
