import { defineConfig } from '@playwright/test';

export default defineConfig({
  testDir: './tests',
  testMatch: '**/full_path.spec.ts',
  fullyParallel: false,
  // Projects own independent contexts, HTTP fixtures and snapshot paths.
  // Each project's file stays sequential; mobile and desktop may run together.
  workers: 2,
  retries: 0,
  // Playwright's default creates missing snapshots. Ordinary verification must
  // never write baselines; only the runner's explicit update command may do so.
  updateSnapshots: 'none',
  metadata: {
    optimizationLevel: process.env.QA_BROWSER_OPTIMIZATION_LEVEL ?? '4',
    flutterTarget: 'test_driver/qa_main.dart',
    backend: 'https://qa.invalid',
  },
  timeout: 90_000,
  expect: {
    timeout: 30_000,
    toHaveScreenshot: {
      animations: 'disabled',
      caret: 'hide',
      maxDiffPixels: 0,
      threshold: 0,
    },
  },
  outputDir: '../../build/browser-results',
  snapshotPathTemplate: '{testDir}/../snapshots/{platform}/{projectName}/{arg}{ext}',
  reporter: [
    ['list'],
    ['html', { outputFolder: '../../build/browser-report', open: 'never' }],
    ['junit', { outputFile: '../../build/browser-results/results.xml' }],
  ],
  use: {
    baseURL: process.env.QA_BROWSER_BASE_URL ?? 'http://127.0.0.1:8765',
    browserName: 'chromium',
    headless: true,
    actionTimeout: 20_000,
    navigationTimeout: 45_000,
    deviceScaleFactor: 1,
    locale: 'ru-RU',
    timezoneId: 'UTC',
    colorScheme: 'light',
    reducedMotion: 'reduce',
    serviceWorkers: 'block',
    trace: 'retain-on-failure',
    screenshot: 'only-on-failure',
    video: 'off',
  },
  projects: [
    { name: 'chromium-mobile', use: { viewport: { width: 390, height: 844 } } },
    { name: 'chromium-desktop', use: { viewport: { width: 1440, height: 1000 } } },
  ],
});
