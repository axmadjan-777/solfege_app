import { test, expect } from '@playwright/test';
import { QaBackend, accountA, accountB, fixedTime, fixtureAnswer, password } from './backend';
import {
  back, button, completeCoachTour, completeFreshToneLesson, completeNoteLesson, completePitchLesson, enterText, findInList, findLesson, focusChatSendForScreenshot,
  login, progressKey, readAccessibleMessage, readProgress, readTextInput, screenshot, seedOnlyNoteAnchors, skipCoach, tab,
} from './driver';

test('onboarding → registration → pending → email confirmation → fresh-user shell',
  async ({ page, context, browser, baseURL }, testInfo) => {
    test.setTimeout(240_000);
    const backend = new QaBackend();
    await backend.install(context);
    await page.clock.setFixedTime(fixedTime);
    await page.goto('/');
    await expect(button(page, 'Начать')).toBeVisible();
    await screenshot(page, 'welcome');
    await button(page, 'Начать').click();
    await enterText(page, page.getByRole('textbox', { name: /^Имя/ }), accountA.name);
    await button(page, 'Далее').click();
    await expect(page.getByText('Выбранный возраст: 18', { exact: true })).toBeVisible();
    await button(page, 'Далее').click();
    await expect(page.getByText('Ваш уровень', { exact: true })).toBeVisible();
    await button(page, 'Продолжить').click();
    await button(page, 'Создать аккаунт').click();
    await enterText(page, page.getByRole('textbox', { name: 'Email', exact: true }), accountA.email);
    await enterText(page, page.getByRole('textbox', { name: 'Пароль', exact: true }), password);
    await enterText(page, page.getByRole('textbox', { name: 'Подтвердите пароль', exact: true }), password);
    await button(page, 'Зарегистрироваться').click();
    await expect(page.getByText('Подтвердите email', { exact: true })).toBeVisible();
    expect(backend.requests.filter((item) => item.path === '/auth/v1/signup')).toHaveLength(1);
    await screenshot(page, 'registration-pending');

    // Reload a pending registration before opening a normal implicit email link.
    await page.reload();
    await expect(page.getByText('Подтвердите email', { exact: true })).toBeVisible();
    await button(page, 'Я подтвердил email').click();
    await expect(page.locator('flt-semantics').getByText(/Откройте ссылку из письма — подтверждение/)).toBeVisible();
    // Leave the SPA document before opening the email redirect. A fragment-only
    // navigation inside an existing Flutter document is handled by its router.
    await page.goto('about:blank');
    await page.goto(`/${backend.confirmationFragment(accountA)}`);
    await expect(page.getByText('Email подтверждён', { exact: true })).toBeVisible();
    await screenshot(page, 'email-confirmed');
    expect(backend.profiles.get(accountA.id)).toMatchObject({
      id: accountA.id, display_name: accountA.name, age: 18,
      musician_level: 'beginner', onboarding_completed: true,
    });
    expect(backend.requests.some((item) => item.method === 'POST' && item.path === '/rest/v1/profiles')).toBe(true);
    await button(page, 'Старт').click();
    await expect(page.getByRole('tab', { name: 'Теория', exact: true })).toBeVisible();
    await completeCoachTour(page);
    expect(await readProgress(page, accountA.id)).toBeNull();
    await tab(page, 'Гаммы');
    await screenshot(page, 'main-shell');
    expect(await readProgress(page, accountA.id)).toBeNull();

    // No seed and no gate override: a fresh account can enter only its actual
    // available lesson, and completing it cannot invent a delayed mastery.
    await tab(page, 'Теория');
    const first = await findLesson(page, 'L00-01');
    await expect(first).toContainText('Открыто');
    await expect(await findLesson(page, 'L00-02')).toContainText('Закрыто');
    await screenshot(page, 'fresh-theory-gates');
    await first.click();
    await completeFreshToneLesson(page);
    await screenshot(page, 'fresh-lesson-summary');
    await expect.poll(async () => (await readProgress(page, accountA.id))?.attempts.length).toBe(11);
    const fresh = await readProgress(page, accountA.id);
    expect(Object.keys(fresh!.competencies)).toEqual(['snd.tone_vs_noise']);
    expect(fresh!.competencies['snd.tone_vs_noise'].status).not.toBe('mastered');
    await button(page, 'Контрольная практика').click();
    await expect(button(page, 'Слушать')).toBeVisible();
    await expect(button(page, 'можно спеть')).toBeDisabled();
    await screenshot(page, 'tone-control-practice');
    await button(page, 'Слушать').click();
    await expect(button(page, 'можно спеть')).toBeEnabled();
    await button(page, 'можно спеть').click();
    await expect(page.getByText('Предварительно сдано', { exact: true })).toBeVisible();
    await expect(button(page, 'Начать холодную проверку')).toBeDisabled();
    await screenshot(page, 'tone-cold-wait');
    const provisional = await readProgress(page, accountA.id);
    expect(provisional!.attempts).toHaveLength(12);
    expect(provisional!.competencies['snd.tone_vs_noise'].status).toBe('provisionally_passed');
    await button(page, 'К теории').click();
    await expect(await findLesson(page, 'L00-02')).toContainText('Закрыто');
    await page.reload();
    await expect(page.getByRole('tab', { name: 'Теория', exact: true })).toBeVisible();
    expect(await readProgress(page, accountA.id)).toEqual(provisional);
    await tab(page, 'Теория');
    await expect(await findLesson(page, 'L00-02')).toContainText('Закрыто');

    const state = await context.storageState({ path: testInfo.outputPath('fresh-persisted-storage.json') });
    const restarted = await browser.newContext({
      storageState: state, baseURL, viewport: page.viewportSize()!,
      deviceScaleFactor: 1, locale: 'ru-RU', timezoneId: 'UTC',
      colorScheme: 'light', reducedMotion: 'reduce', serviceWorkers: 'block',
    });
    await backend.install(restarted);
    const reopened = await restarted.newPage();
    await reopened.clock.setFixedTime(new Date(fixedTime.getTime() + 21 * 60 * 60 * 1000));
    try {
      await reopened.goto('/');
      await expect(reopened.getByRole('tab', { name: 'Теория', exact: true })).toBeVisible();
      expect(await readProgress(reopened, accountA.id)).toEqual(provisional);
      await tab(reopened, 'Теория');
      await reopened.locator('[flt-semantics-identifier="lesson-review-open-L00-01"]').click();
      await expect(button(reopened, 'Начать холодную проверку')).toBeEnabled();
      await button(reopened, 'Начать холодную проверку').click();
      await screenshot(reopened, 'tone-cold-question');
      for (const [index, answer] of ['можно спеть', 'нельзя спеть', 'нельзя спеть', 'можно спеть'].entries()) {
        await expect(button(reopened, answer)).toBeDisabled();
        await button(reopened, 'Слушать').click();
        await expect(button(reopened, answer)).toBeEnabled();
        await button(reopened, answer).click();
        if (index < 3) {
          expect((await readProgress(reopened, accountA.id))!.attempts).toHaveLength(12);
          await expect(reopened.getByText('Освоено', { exact: true })).toHaveCount(0);
          await expect(reopened.getByText('Верно', { exact: true })).toHaveCount(0);
        }
      }
      await expect(reopened.getByText('Освоено', { exact: true })).toBeVisible();
      await expect(reopened.getByText('Верно 4 из 4', { exact: true })).toBeVisible();
      await screenshot(reopened, 'tone-cold-mastered');
      const mastered = await readProgress(reopened, accountA.id);
      expect(mastered!.competencies['snd.tone_vs_noise'].status).toBe('mastered');
      expect(mastered!.attempts).toHaveLength(16);
      const cold = mastered!.attempts.filter((item) => item.cold_review);
      expect(cold).toHaveLength(4);
      expect(new Set(cold.map((item) => item.session_id)).size).toBe(1);
      await button(reopened, 'К теории').click();
      const next = await findLesson(reopened, 'L00-02');
      await expect(next).toContainText('Открыто');
      await screenshot(reopened, 'fresh-theory-unlocked');
      await next.click();
      await completePitchLesson(reopened);
      await button(reopened, 'Тренировать').click();
      await expect(reopened.getByText('Ежедневный микс', { exact: true })).toBeVisible();
      await expect(button(reopened, 'Начать')).toBeVisible();
      await screenshot(reopened, 'fresh-linked-practice');
      const beforeMix = await readProgress(reopened, accountA.id);
      await button(reopened, 'Начать').click();
      await expect(reopened.getByRole('heading', { name: 'Выше и ниже', exact: true })).toBeVisible();
      await completePitchLesson(reopened);
      await button(reopened, 'Продолжить').click();
      await expect.poll(async () => (await readProgress(reopened, accountA.id))!.attempts.length)
        .toBe(beforeMix!.attempts.length + 2);
      await screenshot(reopened, 'fresh-mix-saved');
      await button(reopened, 'Дальше').click();
      await expect(reopened.getByRole('heading', { name: 'Выше и ниже', exact: true })).toBeVisible();
      await expect(button(reopened, 'Дальше')).toBeVisible();
      const finalBook = await readProgress(reopened, accountA.id);
      expect(finalBook!.competencies['snd.tone_vs_noise'].status).toBe('mastered');
      expect(finalBook!.attempts.filter((item) => item.competency_id === 'snd.pitch_direction')).toHaveLength(4);
      await reopened.reload();
      await expect(reopened.getByRole('tab', { name: 'Теория', exact: true })).toBeVisible();
      expect(await readProgress(reopened, accountA.id)).toEqual(finalBook);
      backend.assertNoUnexpectedRequests();
    } finally {
      await restarted.close();
    }
  });

test('recovery link → new password → shell remains available after reload', async ({ page, context }) => {
  const backend = new QaBackend();
  await backend.install(context);
  await page.clock.setFixedTime(fixedTime);
  await page.goto(`/${backend.recoveryFragment(accountA)}`);
  await expect(page.getByRole('heading', { name: 'Новый пароль', exact: true })).toBeVisible();
  await screenshot(page, 'password-recovery');
  await page.reload();
  await expect(page.getByRole('heading', { name: 'Новый пароль', exact: true })).toBeVisible();
  const changedPassword = 'QaChangedFixture43!';
  await enterText(page, page.getByRole('textbox', { name: 'Новый пароль', exact: true }), changedPassword);
  await enterText(page, page.getByRole('textbox', { name: 'Подтвердите пароль', exact: true }), changedPassword);
  await button(page, 'Сохранить новый пароль').click();
  await expect(page.getByRole('tab', { name: 'Теория', exact: true })).toBeVisible();
  await skipCoach(page);
  expect(backend.requests.some((request) => request.method === 'PUT' && request.path === '/auth/v1/user' &&
    request.body?.password === changedPassword)).toBe(true);
  await page.reload();
  await expect(page.getByRole('tab', { name: 'Теория', exact: true })).toBeVisible();
  await expect(page.getByRole('heading', { name: 'Новый пароль', exact: true })).toHaveCount(0);
  backend.assertNoUnexpectedRequests();
});

test('shell → theory → summary → linked practice → mastery, persistence and A → B → A',
  async ({ page, context, browser, baseURL }, testInfo) => {
    test.setTimeout(240_000);
    const backend = new QaBackend();
    await backend.install(context);
    await page.clock.setFixedTime(fixedTime);
    await page.goto('/');
    await expect(button(page, 'Начать')).toBeVisible();
    await seedOnlyNoteAnchors(page);
    // Hydrate SharedPreferences' real cache from the serialized browser seed.
    await page.reload();
    await expect(button(page, 'Начать')).toBeVisible();
    await login(page, accountA);
    await tab(page, 'Теория');
    const target = await findLesson(page, 'L03-04');
    await expect(target).toContainText('Открыто');
    await expect(await findLesson(page, 'L03-05')).toContainText('Закрыто');
    await (await findLesson(page, 'L03-04')).click();
    await screenshot(page, 'note-lesson');
    await completeNoteLesson(page);
    await screenshot(page, 'note-lesson-summary');
    await button(page, 'Тренировать').click();
    await expect(page.getByText('Опоры и соседи (C4–G4)', { exact: true })).toBeVisible();
    const titleBox = await page.getByRole('heading', { name: 'Опоры и соседи (C4–G4)', exact: true }).boundingBox();
    const statusBox = await page.getByText('Предварительно сдано', { exact: true }).boundingBox();
    const answerBox = await button(page, 'соль').boundingBox();
    expect(Boolean(titleBox && statusBox && answerBox &&
      statusBox.y >= titleBox.y + titleBox.height && statusBox.y >= answerBox.y + answerBox.height),
    'saved status must have space below the app bar and answer buttons').toBe(true);
    await screenshot(page, 'linked-note-practice');
    await button(page, 'до').click();
    await expect(page.getByText('Предварительно сдано', { exact: true })).toBeVisible();
    await screenshot(page, 'practice-saved');
    await expect.poll(async () => (await readProgress(page, accountA.id))?.competencies['not.read_treble_c4_g4'].status)
      .toBe('provisionally_passed');
    const saved = await readProgress(page, accountA.id);
    expect(saved!.user_id).toBe(accountA.id);
    expect(saved!.attempts.filter((item) => item.competency_id === 'not.read_treble_c4_g4')).toHaveLength(14);

    // Actual SystemClock is still used. Only the browser's wall clock advances,
    // exercising the production 20-hour wait and cold-session rules.
    await button(page, 'Холодная проверка').click();
    await expect(page.getByText('Рано', { exact: true })).toBeVisible();
    const later = new Date(fixedTime.getTime() + 21 * 60 * 60 * 1000);
    await page.clock.setFixedTime(later);
    await button(page, 'Холодная проверка').click();
    for (let i = 0; i < 4; i += 1) {
      await button(page, 'до').click();
      if (i < 3) await button(page, 'Следующее').click();
    }
    await expect(page.getByText('Освоено', { exact: true })).toBeVisible();
    await screenshot(page, 'practice-mastered');
    const mastered = await readProgress(page, accountA.id);
    expect(mastered!.competencies['not.read_treble_c4_g4'].status).toBe('mastered');
    expect(mastered!.attempts.filter((item) => item.competency_id === 'not.read_treble_c4_g4' && item.cold_review)).toHaveLength(4);
    await back(page);
    await back(page);
    const unlocked = await findLesson(page, 'L03-05');
    await expect(unlocked).toContainText('Открыто');
    await screenshot(page, 'theory-unlocked');
    await unlocked.click();
    await expect(button(page, 'Дальше')).toBeVisible();
    await expect(page.getByText('Ноты A4–G5 и добавочные линии вниз', { exact: true })).toBeVisible();
    await back(page);

    await page.reload();
    await expect(page.getByRole('tab', { name: 'Теория', exact: true })).toBeVisible();
    expect(await readProgress(page, accountA.id)).toEqual(mastered);
    await tab(page, 'Теория');
    await expect(await findLesson(page, 'L03-05')).toContainText('Открыто');

    // Recreate the browser context using the browser's real persisted storage.
    // Do not seed a session or reconstruct progress from expected values.
    const state = await context.storageState({ path: testInfo.outputPath('persisted-storage.json') });
    expect(state.origins.flatMap((origin) => origin.localStorage).some((item) => item.name === progressKey(accountA.id))).toBe(true);
    const restarted = await browser.newContext({
      storageState: state, baseURL, viewport: page.viewportSize()!,
      deviceScaleFactor: 1, locale: 'ru-RU', timezoneId: 'UTC',
      colorScheme: 'light', reducedMotion: 'reduce', serviceWorkers: 'block',
    });
    await backend.install(restarted);
    const reopened = await restarted.newPage();
    await reopened.clock.setFixedTime(later);
    try {
      await reopened.goto('/');
      await expect(reopened.getByRole('tab', { name: 'Теория', exact: true })).toBeVisible();
      expect(await readProgress(reopened, accountA.id)).toEqual(mastered);
      await tab(reopened, 'Теория');
      await expect(await findLesson(reopened, 'L03-05')).toContainText('Открыто');
      await screenshot(reopened, 'restarted-theory');
      await tab(reopened, 'ИИ');
      let releaseReply: () => void = () => {};
      const replyGate = new Promise<void>((resolve) => { releaseReply = resolve; });
      await reopened.route('**/functions/v1/gemini-chat', async (route) => {
        await replyGate;
        await route.fallback();
      });
      await enterText(reopened, reopened.getByRole('textbox', { name: 'Задайте вопрос о музыке…', exact: true }),
        'Что такое тоника?');
      try {
        await button(reopened, 'Отправить').click();
        await reopened.mouse.move(0, 0);
        // Guarantee the loading frame that previously dropped Send's focus.
        await expect(button(reopened, 'Отправить')).toBeDisabled();
      } finally {
        releaseReply();
      }
      const modelMessage = reopened.locator('[flt-semantics-identifier="ai-message-model"]');
      expect(await readAccessibleMessage(modelMessage)).toBe(fixtureAnswer);
      await focusChatSendForScreenshot(reopened);
      await screenshot(reopened, 'fixture-ai-chat');
      await tab(reopened, 'Профиль');
      await (await findInList(reopened, button(reopened, 'Выйти из аккаунта'), 'Logout')).click();
      await expect(button(reopened, 'Начать')).toBeVisible();
      await login(reopened, accountB);
      await tab(reopened, 'Профиль');
      expect(await readTextInput(reopened, reopened.getByRole('textbox', { name: 'Имя', exact: true }))).toBe(accountB.name);
      expect(await readProgress(reopened, accountB.id)).toBeNull();
      expect(await readProgress(reopened, accountA.id)).toEqual(mastered);
      await tab(reopened, 'Теория');
      await expect(await findLesson(reopened, 'L03-04')).toContainText('Закрыто');
      await expect(await findLesson(reopened, 'L03-05')).toContainText('Закрыто');
      await screenshot(reopened, 'account-b-isolated');
      await tab(reopened, 'Профиль');
      await (await findInList(reopened, button(reopened, 'Выйти из аккаунта'), 'Logout')).click();
      await expect(button(reopened, 'Начать')).toBeVisible();
      await login(reopened, accountA);
      await tab(reopened, 'Профиль');
      expect(await readTextInput(reopened, reopened.getByRole('textbox', { name: 'Имя', exact: true }))).toBe(accountA.name);
      await tab(reopened, 'Теория');
      await expect(await findLesson(reopened, 'L03-05')).toContainText('Открыто');
      expect(await readProgress(reopened, accountA.id)).toEqual(mastered);
      backend.assertNoUnexpectedRequests();
    } finally {
      await restarted.close();
    }
  });
