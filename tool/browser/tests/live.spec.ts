import { test, expect, type BrowserContext, type Route } from '@playwright/test';
import { button, enterText, findInList, findLesson, readAccessibleMessage, readProgress, readTextInput, skipCoach, tab } from './driver';

function setting(name: string): string {
  const value = process.env[name];
  if (!value) throw new Error(`Missing required setting: ${name}`);
  return value;
}

interface LiveState {
  failed: boolean;
  currentUserId: string | null;
  profile: Record<string, unknown> | null;
  answer: string;
  geminiResponses: number;
  http: string[];
}

async function installProxy(context: BrowserContext, state: LiveState): Promise<void> {
  const upstream = new URL(setting('QA_SUPABASE_URL'));
  const key = setting('QA_SUPABASE_PUBLISHABLE_KEY');
  const projectRef = setting('QA_PROJECT_REF');
  if (setting('QA_LIVE') !== '1' || !/^[a-z0-9]{20}$/.test(projectRef) ||
      upstream.host !== `${projectRef}.supabase.co` || upstream.pathname !== '/' ||
      upstream.username || upstream.password || upstream.search || upstream.hash ||
      upstream.protocol !== 'https:' ||
      !key.startsWith('sb_publishable_')) {
    throw new Error('Live browser requires explicit QA_LIVE=1 and a matching HTTPS project/client-key configuration');
  }
  const handle = async (route: Route) => {
    const request = route.request();
    const url = new URL(request.url());
    if (url.protocol === 'blob:' || url.protocol === 'data:') {
      await route.continue();
      return;
    }
    if (url.hostname === '127.0.0.1' || url.hostname === 'localhost') {
      await route.continue();
      return;
    }
    const preflight = request.method() === 'OPTIONS' && new Set([
      '/auth/v1/token', '/auth/v1/user', '/auth/v1/logout',
      '/rest/v1/profiles', '/functions/v1/gemini-chat',
    ]).has(url.pathname);
    const allowed = url.origin === 'https://qa.invalid' && (preflight ||
      (url.pathname === '/auth/v1/token' && request.method() === 'POST') ||
      (url.pathname === '/auth/v1/user' && request.method() === 'GET') ||
      (url.pathname === '/auth/v1/logout' && request.method() === 'POST') ||
      (url.pathname === '/rest/v1/profiles' && request.method() === 'GET') ||
      (url.pathname === '/functions/v1/gemini-chat' && request.method() === 'POST')
    );
    if (!allowed) {
      state.failed = true;
      await route.abort('blockedbyclient');
      return;
    }
    try {
      const headers: Record<string, string> = { ...request.headers(), apikey: key };
      delete headers.host;
      if (headers.authorization === 'Bearer sb_publishable_qa_fixture') {
        headers.authorization = `Bearer ${key}`;
      }
      const destination = new URL(url.pathname + url.search, upstream.origin);
      const response = await route.fetch({ url: destination.href, headers, timeout: 90_000 });
      const service = url.pathname.startsWith('/auth/') ? 'auth'
        : url.pathname.startsWith('/rest/') ? 'profiles' : 'gemini';
      state.http.push(`${service}:${response.status()}`);
      if (response.status() >= 400) state.failed = true;
      if (url.pathname === '/auth/v1/token' && response.ok()) {
        const data = await response.json();
        state.currentUserId = data.user?.id ?? null;
      } else if (url.pathname === '/rest/v1/profiles' && response.ok()) {
        const data = await response.json();
        state.profile = Array.isArray(data) ? data[0] ?? null : data;
      } else if (url.pathname === '/functions/v1/gemini-chat' && response.ok()) {
        const data = await response.json();
        state.answer = typeof data.answer === 'string' ? data.answer : '';
        state.geminiResponses += 1;
      }
      // The response body/status come from the real service unchanged. Only
      // transport destination, client key and CORS origin are adapted.
      await route.fulfill({ response, headers: {
        ...response.headers(),
        'access-control-allow-origin': new URL(request.headers().origin ?? 'http://127.0.0.1').origin,
      } });
    } catch {
      state.failed = true;
      await route.abort('failed').catch(() => {});
    }
  };
  await context.route('**/*', handle);
}

test('live A/B sign-in, own profile and real Gemini answer', async ({ page, context }, testInfo) => {
  // No browser clock override in live mode: real Auth expiration/refresh rules
  // must use actual time. No registration, email, or password-reset calls.
  const a = { email: setting('QA_USER_A_EMAIL'), password: setting('QA_USER_A_PASSWORD'), id: setting('QA_USER_A_ID') };
  const b = { email: setting('QA_USER_B_EMAIL'), password: setting('QA_USER_B_PASSWORD'), id: setting('QA_USER_B_ID') };
  const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
  if (!uuid.test(a.id) || !uuid.test(b.id) || a.id.toLowerCase() === b.id.toLowerCase() ||
      a.email.trim().toLowerCase() === b.email.trim().toLowerCase()) {
    throw new Error('Live browser requires two distinct dedicated QA accounts and UUIDs');
  }
  const state: LiveState = { failed: false, currentUserId: null, profile: null, answer: '', geminiResponses: 0, http: [] };
  await installProxy(context, state);
  const signIn = async (account: typeof a, who: 'A' | 'B') => {
    await button(page, 'Уже есть аккаунт? Войти').click();
    await enterText(page, page.getByRole('textbox', { name: 'Email', exact: true }), account.email);
    await enterText(page, page.getByRole('textbox', { name: 'Пароль', exact: true }), account.password);
    await button(page, 'Войти').click();
    await test.step(`${who} shell visible`, async () => {
      await expect(page.getByRole('tab', { name: 'Теория', exact: true })).toBeVisible();
    });
    await test.step(`${who} guided coach skipped`, async () => skipCoach(page));
    await tab(page, 'Профиль');
    await test.step(`${who} auth/profile identity matches`, async () => {
      await expect.poll(() => state.currentUserId === account.id && state.profile?.id === account.id).toBe(true);
    });
    await test.step(`${who} profile editor value matches`, async () => {
      const displayed = await readTextInput(page, page.getByRole('textbox', { name: 'Имя', exact: true }));
      expect(displayed === state.profile?.display_name).toBe(true);
    });
  };
  const signOut = async () => {
    await tab(page, 'Профиль');
    await (await findInList(page, button(page, 'Выйти из аккаунта'), 'Logout')).click();
    await expect(button(page, 'Начать')).toBeVisible();
  };
  try {
    await page.goto('/');
    await test.step('A sign-in and own profile', async () => signIn(a, 'A'));
    await test.step('A real Gemini reply', async () => {
      await tab(page, 'ИИ');
      await enterText(page, page.getByRole('textbox', { name: 'Задайте вопрос о музыке…', exact: true }),
        'Назови три ноты тонического трезвучия До мажор по-русски и качество аккорда. Ответь кратко, одним предложением.');
      await test.step('A Gemini request sent', async () => button(page, 'Отправить').click());
      await test.step('A genuine Gemini response received', async () => {
        await expect.poll(() => state.geminiResponses === 1 && state.answer.trim().length > 0,
          { timeout: 100_000 }).toBe(true);
      });
      await test.step('A genuine Gemini answer rendered', async () => {
        const modelMessage = page.locator('[flt-semantics-identifier="ai-message-model"]');
        await expect.poll(async () => (await readAccessibleMessage(modelMessage)) ===
          state.answer.replace(/\r\n/g, '\n').trim()).toBe(true);
      });
    });
    await test.step('A logout', signOut);
    await test.step('B sign-in and own profile/progress', async () => {
      await signIn(b, 'B');
      const own = await readProgress(page, b.id);
      expect(own === null || own.user_id === b.id).toBe(true);
      await tab(page, 'Теория');
      await expect(await findLesson(page, 'L00-01')).toContainText('Открыто');
      await expect(await findLesson(page, 'L00-02')).toContainText('Закрыто');
    });
    await test.step('B logout', signOut);
    expect(state.failed).toBe(false);
    expect(state.geminiResponses).toBe(1);
  } catch {
    // Reporter and on-disk error context must not receive raw locator arguments,
    // response bodies, names/emails/passwords, or bearer tokens.
    throw new Error('Live browser acceptance failed; see sanitized phase/status report.');
  } finally {
    for (const status of state.http) {
      testInfo.annotations.push({ type: 'live-http', description: status });
    }
  }
});
