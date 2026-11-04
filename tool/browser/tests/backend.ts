import { expect, type BrowserContext, type Route } from '@playwright/test';

export const fixedTime = new Date('2026-11-04T09:00:00.000Z');
export const accountA = {
  id: '11111111-1111-4111-8111-111111111111',
  email: 'anna.qa@example.invalid',
  name: 'Анна QA',
};
export const accountB = {
  id: '22222222-2222-4222-8222-222222222222',
  email: 'boris.qa@example.invalid',
  name: 'Борис QA',
};
export const password = 'QaFixtureOnly42!';
export const fixtureAnswer = 'QA: устойчивая ступень I называется тоникой.';
export type Account = typeof accountA;

type Json = Record<string, unknown>;

// These are HTTP fixtures, not replacement Flutter services. The browser still
// runs the real Supabase SDK, AuthService, ProfileService and production routes.
export class QaBackend {
  readonly requests: { method: string; path: string; body: Json | null }[] = [];
  readonly unexpected: string[] = [];
  readonly profiles = new Map<string, Json>();
  readonly metadata = new Map<string, Json>();
  readonly confirmed = new Set<string>();
  readonly passwords = new Map<string, string>();

  constructor() {
    for (const account of [accountA, accountB]) {
      this.metadata.set(account.id, {
        display_name: account.name,
        age: 18,
        musician_level: 'beginner',
      });
      this.confirmed.add(account.id);
      this.passwords.set(account.id, password);
      this.profiles.set(account.id, {
        id: account.id,
        display_name: account.name,
        age: 18,
        musician_level: 'beginner',
        onboarding_completed: true,
        preferred_note_language: 'ru_solfege',
      });
    }
  }

  user(account: Account): Json {
    return {
      id: account.id,
      aud: 'authenticated',
      role: 'authenticated',
      email: account.email,
      email_confirmed_at: this.confirmed.has(account.id)
        ? '2026-11-04T09:00:00.000Z' : null,
      phone: '',
      created_at: '2026-11-01T09:00:00.000Z',
      updated_at: '2026-11-04T09:00:00.000Z',
      app_metadata: { provider: 'email', providers: ['email'] },
      user_metadata: this.metadata.get(account.id),
      identities: [],
    };
  }

  token(account: Account): string {
    const encode = (value: Json) => Buffer.from(JSON.stringify(value)).toString('base64url');
    return `${encode({ alg: 'HS256', typ: 'JWT' })}.${encode({
      sub: account.id, aud: 'authenticated', role: 'authenticated',
      email: account.email,
      iat: Math.floor(fixedTime.getTime() / 1000),
      exp: Math.floor(fixedTime.getTime() / 1000) + 604800,
    })}.qa-fixture-signature`;
  }

  session(account: Account): Json {
    return {
      access_token: this.token(account),
      token_type: 'bearer',
      expires_in: 604800,
      expires_at: Math.floor(fixedTime.getTime() / 1000) + 604800,
      refresh_token: `qa-refresh-${account.id}`,
      user: this.user(account),
    };
  }

  confirmationFragment(account: Account): string {
    this.confirmed.add(account.id);
    return `#${new URLSearchParams({
      access_token: this.token(account),
      refresh_token: `qa-refresh-${account.id}`,
      expires_in: '604800', token_type: 'bearer', type: 'signup',
    })}`;
  }

  recoveryFragment(account: Account): string {
    return this.confirmationFragment(account).replace('type=signup', 'type=recovery');
  }

  async install(context: BrowserContext): Promise<void> {
    context.on('response', (response) => {
      const url = new URL(response.url());
      if ((url.hostname === '127.0.0.1' || url.hostname === 'localhost') && response.status() >= 400) {
        this.unexpected.push(`HTTP ${response.status()} ${url.pathname}`);
      }
    });
    const watch = (page: import('@playwright/test').Page) => {
      page.on('pageerror', (error) => this.unexpected.push(`pageerror: ${error.message}`));
    };
    context.pages().forEach(watch);
    context.on('page', watch);
    await context.route('**/*', async (route) => this.handle(route));
  }

  assertNoUnexpectedRequests(): void {
    expect(this.unexpected, 'browser must load local assets without errors and use only the isolated HTTP backend').toEqual([]);
  }

  private async handle(route: Route): Promise<void> {
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
    if (url.origin !== 'https://qa.invalid') {
      this.unexpected.push(`${request.method()} ${url.origin}${url.pathname}`);
      await route.abort('blockedbyclient');
      return;
    }

    const method = request.method();
    const path = url.pathname;
    const body = request.postData() ? request.postDataJSON() as Json : null;
    this.requests.push({ method, path, body });
    const headers = {
      'access-control-allow-origin': '*',
      'access-control-allow-headers': '*',
      'access-control-allow-methods': 'GET,POST,PATCH,DELETE,OPTIONS',
      'content-type': 'application/json',
    };
    const json = async (value: unknown, status = 200) =>
      route.fulfill({ status, headers, body: JSON.stringify(value) });
    if (method === 'OPTIONS') {
      await route.fulfill({ status: 204, headers });
      return;
    }
    const authorization = request.headers()['authorization'] ?? '';
    const account = [accountA, accountB].find((item) => authorization === `Bearer ${this.token(item)}`);

    if (path === '/auth/v1/signup' && method === 'POST') {
      expect(body?.email).toBe(accountA.email);
      expect(body?.password).toBe(password);
      this.metadata.set(accountA.id, body?.data as Json);
      this.profiles.delete(accountA.id);
      this.confirmed.delete(accountA.id);
      await json(this.user(accountA));
    } else if (path === '/auth/v1/token' && method === 'POST') {
      const selected = url.searchParams.get('grant_type') === 'refresh_token'
        ? [accountA, accountB].find((item) => body?.refresh_token === `qa-refresh-${item.id}`)
        : [accountA, accountB].find((item) => body?.email === item.email && body?.password === this.passwords.get(item.id));
      await (selected ? json(this.session(selected)) : json({ msg: 'Invalid login credentials' }, 400));
    } else if (path === '/auth/v1/user' && method === 'GET' && account) {
      await json(this.user(account));
    } else if (path === '/auth/v1/user' && method === 'PUT' && account && typeof body?.password === 'string') {
      this.passwords.set(account.id, body.password);
      await json(this.user(account));
    } else if (path === '/auth/v1/logout' && method === 'POST' && account) {
      await route.fulfill({ status: 204, headers });
    } else if (path === '/auth/v1/resend' && method === 'POST') {
      await json({});
    } else if (path === '/rest/v1/profiles' && account) {
      const filteredId = url.searchParams.get('id');
      if (filteredId && filteredId !== `eq.${account.id}`) {
        await json({ message: 'QA fixture rejects another account id' }, 403);
        return;
      }
      if (method === 'POST') {
        expect(body?.id).toBe(account.id);
        this.profiles.set(account.id, body!);
      } else if (method === 'PATCH') {
        this.profiles.set(account.id, { ...this.profiles.get(account.id), ...body });
      } else if (method !== 'GET') {
        this.unexpected.push(`${method} ${path}`);
        await json({ message: 'Unexpected profile operation' }, 500);
        return;
      }
      const profile = this.profiles.get(account.id);
      const isObject = (request.headers()['accept'] ?? '').includes('application/vnd.pgrst.object+json');
      await json(isObject ? profile ?? null : profile ? [profile] : []);
    } else if (path === '/functions/v1/gemini-chat' && method === 'POST' && account) {
      await json({ answer: fixtureAnswer });
    } else {
      this.unexpected.push(`${method} ${path}`);
      await json({ message: 'Unexpected QA fixture request' }, 500);
    }
  }
}
