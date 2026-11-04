import {
  ConfigError,
  ENV_NAMES,
  type Environment,
  validateConfig,
} from "./config.ts";
import {
  type CheckResult,
  type EvaluationArtifact,
  type LiveReport,
  writeReport,
} from "./report.ts";
import { runSuite } from "./suite.ts";

function argumentsForRun(
  args: string[],
): { preflight: boolean; directory: string } {
  let preflight = false;
  let directory = "build/qa-live";
  for (let index = 0; index < args.length; index++) {
    const argument = args[index];
    if (argument === "--preflight" && !preflight) preflight = true;
    else if (
      argument === "--report-dir" && args[index + 1] &&
      !args[index + 1].startsWith("-")
    ) {
      directory = args[++index];
    } else {
      throw new ConfigError(
        "Usage: bash tool/verify_live.sh [--preflight] [--report-dir PATH].",
      );
    }
  }
  return { preflight, directory };
}

const startedAt = new Date().toISOString();
const runId = crypto.randomUUID();
let options: { preflight: boolean; directory: string };
try {
  options = argumentsForRun(Deno.args);
} catch {
  console.error(
    "Usage: bash tool/verify_live.sh [--preflight] [--report-dir PATH].",
  );
  Deno.exit(2);
}
const report: LiveReport = {
  schemaVersion: 1,
  suite: "solfege-hosted-services",
  runId,
  startedAt,
  finishedAt: startedAt,
  mode: options.preflight ? "preflight" : "live",
  status: "configuration_error",
  exitCode: 2,
  liveAcceptance: "not_run",
  checks: [],
  cleanup: [],
  limitations: [
    "Only the two explicitly configured QA account UUIDs are accessed; no other profiles are enumerated.",
    "Only display_name is changed and restored; the database trigger may advance updated_at.",
    "Confirmation and password-reset email delivery are not exercised or established by this suite.",
    "Browser navigation and audible playback are not exercised by these HTTP acceptance checks.",
    "Automated Gemini checks establish the response contract and musical content markers; the evaluation artifact needs separate semantic review.",
  ],
};
let evaluation: EvaluationArtifact | undefined;
try {
  const env: Environment = {};
  for (const name of ENV_NAMES) env[name] = Deno.env.get(name);
  const config = validateConfig(env);
  report.projectRef = config.projectRef;
  report.keyKind = config.keyKind;
  const configuration: CheckResult = {
    id: "config",
    name:
      "Explicit opt-in, hosted project, client key, and distinct authorized QA UUIDs",
    status: "passed",
    durationMs: 0,
    detail: "Static configuration validated without contacting any service.",
  };
  report.checks.push(configuration);
  if (options.preflight) {
    report.status = "preflight_passed";
    report.exitCode = 0;
    console.log(
      "Preflight configuration valid. Live acceptance NOT RUN; no network request was made.",
    );
  } else {
    const result = await runSuite(config, runId);
    report.checks.push(...result.checks);
    report.cleanup = result.cleanup;
    evaluation = result.evaluation;
    const failed = [...report.checks, ...report.cleanup].some((check) =>
      check.status !== "passed"
    );
    report.status = failed ? "failed" : "passed";
    report.liveAcceptance = failed ? "failed" : "passed";
    report.exitCode = failed ? 1 : 0;
  }
} catch (error) {
  const configurationError = error instanceof ConfigError;
  const detail = configurationError
    ? error.message
    : "Live runner failed; sensitive exception details withheld.";
  report.checks.push({
    id: configurationError ? "config" : "runner",
    name: "Live suite prerequisite or runner",
    status: "failed",
    durationMs: 0,
    detail,
  });
  report.status = configurationError ? "configuration_error" : "failed";
  report.exitCode = configurationError ? 2 : 1;
  report.liveAcceptance = configurationError ? "not_run" : "failed";
  console.error(detail);
}
report.finishedAt = new Date().toISOString();
try {
  await writeReport(options.directory, report, evaluation);
} catch {
  console.error(
    "Could not write live QA artifacts. Live QA cannot be accepted; details withheld.",
  );
  Deno.exit(3);
}
console.log(
  `Live QA status: ${report.status}; acceptance: ${report.liveAcceptance}; exit ${report.exitCode}.`,
);
Deno.exit(report.exitCode);
