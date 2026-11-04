import { defineConfig } from '@playwright/test';

// Deliberately separate from offline reports: no traces, screenshots, video,
// storageState, HTML, or unsanitized error/call-argument output in live checks.
process.env.PLAYWRIGHT_NO_COPY_PROMPT = '1';

export default defineConfig({
  testDir: './tests',
  testMatch: '**/live.spec.ts',
  fullyParallel: false,
  workers: 1,
  retries: 0,
  timeout: 180_000,
  expect: { timeout: 25_000 },
  outputDir: '../../build/browser-live-private',
  reporter: [['./sanitized_reporter.ts']],
  use: {
    baseURL: process.env.QA_BROWSER_BASE_URL ?? 'http://127.0.0.1:8765',
    browserName: 'chromium',
    headless: true,
    viewport: { width: 1440, height: 1000 },
    deviceScaleFactor: 1,
    locale: 'ru-RU',
    colorScheme: 'light',
    reducedMotion: 'reduce',
    serviceWorkers: 'block',
    actionTimeout: 15_000,
    navigationTimeout: 30_000,
    trace: 'off',
    screenshot: 'off',
    video: 'off',
  },
  projects: [{ name: 'chromium-live' }],
});
