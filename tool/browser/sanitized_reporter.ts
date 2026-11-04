import { mkdirSync, rmSync, writeFileSync } from 'node:fs';
import { resolve } from 'node:path';
import type { FullResult, Reporter, TestCase, TestResult, TestStep } from '@playwright/test/reporter';

const allowedPhases = new Set([
  'A sign-in and own profile', 'A real Gemini reply', 'A logout',
  'B sign-in and own profile/progress', 'B logout',
  'A shell visible', 'A auth/profile identity matches', 'A profile editor value matches',
  'B shell visible', 'B auth/profile identity matches', 'B profile editor value matches',
  'A guided coach skipped', 'B guided coach skipped',
  'A Gemini request sent', 'A genuine Gemini response received', 'A genuine Gemini answer rendered',
]);

export default class SanitizedReporter implements Reporter {
  private phases = new Map<string, string>();
  private results: { status: string; phase: string; duration_ms: number; service_http: string[] }[] = [];

  onStepBegin(test: TestCase, _result: TestResult, step: TestStep): void {
    if (step.category === 'test.step' && allowedPhases.has(step.title)) {
      this.phases.set(test.id, step.title);
    }
  }

  onTestEnd(test: TestCase, result: TestResult): void {
    const phase = this.phases.get(test.id) ?? 'setup';
    const serviceHttp = test.annotations
      .filter((item) => item.type === 'live-http' && /^(auth|profiles|gemini):[1-5][0-9]{2}$/.test(item.description ?? ''))
      .map((item) => item.description!);
    this.results.push({ status: result.status, phase, duration_ms: result.duration, service_http: serviceHttp });
    process.stdout.write(`Live browser: ${result.status}; phase: ${phase}\n`);
    // Never serialize TestResult.errors, steps, attachments, request data, or
    // user-provided text. Even locator call logs can contain a typed password.
  }

  onError(): void {
    process.stderr.write('Live browser runner failed; sensitive error details suppressed.\n');
  }

  onStdOut(): void {}
  onStdErr(): void {}

  onEnd(result: FullResult): void {
    const directory = resolve(__dirname, '../../build/browser-live-results');
    mkdirSync(directory, { recursive: true });
    writeFileSync(resolve(directory, 'results.json'), JSON.stringify({
      status: result.status,
      optimization_level: process.env.QA_BROWSER_OPTIMIZATION_LEVEL ?? '4',
      tests: this.results,
    }, null, 2) + '\n');
    // Playwright can create error-context.md even with tracing disabled. Its
    // private output directory must never be retained or published.
    rmSync(resolve(__dirname, '../../build/browser-live-private'), { recursive: true, force: true });
  }
}
