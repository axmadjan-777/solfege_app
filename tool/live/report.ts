export type CheckStatus = "passed" | "failed" | "blocked";

export interface CheckResult {
  id: string;
  name: string;
  status: CheckStatus;
  durationMs: number;
  detail: string;
}

export interface EvaluationArtifact {
  schemaVersion: 1;
  runId: string;
  source: "deployed_supabase_edge_function";
  function: "gemini-chat";
  requestedAt: string;
  question: string;
  answer: string;
  model: string;
  credentialsRedacted: boolean;
  automatedContract: "passed" | "failed";
  semanticEvaluation: "pending_separate_review";
}

export interface LiveReport {
  schemaVersion: 1;
  suite: "solfege-hosted-services";
  runId: string;
  startedAt: string;
  finishedAt: string;
  mode: "live" | "preflight";
  status: "passed" | "failed" | "configuration_error" | "preflight_passed";
  exitCode: number;
  liveAcceptance: "passed" | "failed" | "not_run";
  projectRef?: string;
  keyKind?: "publishable" | "anon_jwt";
  checks: CheckResult[];
  cleanup: CheckResult[];
  limitations: string[];
}

function escapeXml(value: string): string {
  return value.replaceAll("&", "&amp;").replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;").replaceAll('"', "&quot;")
    .replaceAll("'", "&apos;");
}

export function junit(report: LiveReport): string {
  const results = [...report.checks, ...report.cleanup];
  const failures = results.filter((r) => r.status !== "passed").length;
  const testcases = results.map((result) => {
    const failure = result.status === "passed"
      ? ""
      : `<failure type="${result.status}" message="${
        escapeXml(result.detail)
      }"/>`;
    return `    <testcase classname="solfege.hosted.${report.mode}" name="${
      escapeXml(result.id)
    }" time="${(result.durationMs / 1000).toFixed(3)}">${failure}</testcase>`;
  });
  return `<?xml version="1.0" encoding="UTF-8"?>\n<testsuites>\n  <testsuite name="solfege-hosted-services-${report.mode}" tests="${results.length}" failures="${failures}" skipped="0">\n${
    testcases.join("\n")
  }\n  </testsuite>\n</testsuites>\n`;
}

export async function writeReport(
  directory: string,
  report: LiveReport,
  evaluation?: EvaluationArtifact,
): Promise<void> {
  await Deno.mkdir(directory, { recursive: true, mode: 0o700 });
  // Remove a previous run's answer even when this run failed before Gemini.
  try {
    await Deno.remove(`${directory}/gemini-evaluation.json`);
  } catch (error) {
    if (!(error instanceof Deno.errors.NotFound)) throw error;
  }
  await Deno.writeTextFile(
    `${directory}/summary.json`,
    `${JSON.stringify(report, null, 2)}\n`,
    { mode: 0o600 },
  );
  await Deno.writeTextFile(`${directory}/results.junit.xml`, junit(report), {
    mode: 0o600,
  });
  if (evaluation) {
    await Deno.writeTextFile(
      `${directory}/gemini-evaluation.json`,
      `${JSON.stringify(evaluation, null, 2)}\n`,
      { mode: 0o600 },
    );
  }
}
