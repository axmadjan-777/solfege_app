const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { Module } = require('node:module');
const ts = require('typescript');

// Exercise the actual reporter with synthetic sensitive values. No browser,
// environment credentials or live service is used, and output stays in /tmp.
const temporary = fs.mkdtempSync(path.join(os.tmpdir(), 'solfege-reporter-test-'));
const originalOut = process.stdout.write;
const originalError = process.stderr.write;
let captured = '';
try {
  const directory = path.join(temporary, 'tool/browser');
  fs.mkdirSync(directory, { recursive: true });
  const filename = path.join(directory, 'sanitized_reporter.js');
  const source = fs.readFileSync(path.join(__dirname, '../sanitized_reporter.ts'), 'utf8');
  const compiled = ts.transpileModule(source, {
    compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2023 },
  }).outputText;
  const loaded = new Module(filename, module);
  loaded.filename = filename;
  loaded.paths = module.paths;
  loaded._compile(compiled, filename);
  const reporter = new loaded.exports.default();
  const secrets = ['qa-report-password-sentinel', 'private@example.invalid',
    'eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJwcml2YXRlIn0.private-signature',
    'private-model-answer-sentinel'];
  const privateDirectory = path.join(temporary, 'build/browser-live-private');
  fs.mkdirSync(privateDirectory, { recursive: true });
  fs.writeFileSync(path.join(privateDirectory, 'error-context.md'), secrets.join('\n'));
  process.stdout.write = process.stderr.write = (value) => {
    captured += String(value);
    return true;
  };
  const test = { id: 'synthetic', annotations: [
    { type: 'live-http', description: 'auth:200' },
    { type: 'live-http', description: secrets[1] },
    { type: 'live-http', description: `gemini:200 ${secrets[2]}` },
  ] };
  reporter.onStepBegin(test, {}, { category: 'test.step', title: 'A real Gemini reply' });
  reporter.onStdOut(Buffer.from(secrets[0]));
  reporter.onStdErr(Buffer.from(secrets[1]));
  reporter.onError(new Error(secrets[2]));
  reporter.onTestEnd(test, { status: 'failed', duration: 1,
    errors: [{ message: secrets.join(' ') }], attachments: [{ body: secrets[3] }] });
  reporter.onEnd({ status: 'failed' });
  const reportPath = path.join(temporary, 'build/browser-live-results/results.json');
  const report = fs.readFileSync(reportPath, 'utf8');
  for (const secret of secrets) assert(!`${captured}${report}`.includes(secret));
  assert.deepEqual(JSON.parse(report).tests[0].service_http, ['auth:200']);
  assert(!fs.existsSync(privateDirectory));
} finally {
  process.stdout.write = originalOut;
  process.stderr.write = originalError;
  fs.rmSync(temporary, { recursive: true, force: true });
}
console.log('PASS: sanitized live reporter excludes secrets/raw data and removes private artifacts');
