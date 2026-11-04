import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { expect, type Locator, type Page } from '@playwright/test';
import { accountA, password, type Account } from './backend';

export const progressKey = (id: string) => `flutter.practice_progress_v1:${id}`;

export interface ProgressBook {
  user_id: string;
  competencies: Record<string, { status: string; provisional_at: string | null }>;
  attempts: { competency_id: string; session_id: string; is_correct: boolean; cold_review: boolean }[];
  returns: unknown[];
}

export function button(page: Page, name: string): Locator {
  return page.getByRole('button', { name, exact: true });
}

export async function enterText(page: Page, field: Locator, value: string): Promise<void> {
  // Flutter has a semantics input and a separate focused editing input. Real
  // pointer/keyboard input reaches EditableText's controller; assigning the
  // semantics DOM input with fill() can leave that controller unchanged.
  await page.waitForTimeout(350);
  await field.click();
  await page.waitForTimeout(100);
  await page.keyboard.press('ControlOrMeta+A');
  await page.keyboard.type(value, { delay: 5 });
  await page.keyboard.press('Tab');
}

export async function readTextInput(page: Page, field: Locator): Promise<string> {
  // Unfocused semantics inputs may have an empty DOM value while Flutter paints
  // the controller's text. Focus activates the real editor without changing it.
  await page.waitForTimeout(350);
  await field.click();
  await page.waitForTimeout(100);
  const focused = page.locator('input:focus, textarea:focus');
  return (await focused.count()) === 1 ? focused.inputValue() : field.inputValue();
}

export async function readAccessibleMessage(message: Locator): Promise<string> {
  await expect(message).toBeVisible();
  return message.evaluate((element) => {
    const label = element.getAttribute('aria-label');
    return (label || element.textContent || '').replace(/\r\n/g, '\n').trim();
  });
}

export async function focusChatSendForScreenshot(page: Page): Promise<void> {
  // A fast HTTP fixture can coalesce the loading frame, while a slower reply
  // disables and rebuilds Send and drops its focus. Establish the same real
  // keyboard focus only after the reply has re-enabled the button.
  await page.mouse.move(0, 0);
  await page.waitForTimeout(350);
  const send = button(page, 'Отправить');
  await expect(send).toBeEnabled();
  const composer = page.getByRole('textbox', { name: 'Задайте вопрос о музыке…', exact: true });
  await composer.click();
  await page.waitForTimeout(100);
  await page.keyboard.press('Tab');
  await expect(send).toBeFocused();
  await page.mouse.move(0, 0);
  // Let the real pointer ripple and focus overlay finish before comparison.
  await page.waitForTimeout(1000);
}

export async function login(page: Page, account: Account): Promise<void> {
  await button(page, 'Уже есть аккаунт? Войти').click();
  await enterText(page, page.getByRole('textbox', { name: 'Email', exact: true }), account.email);
  await enterText(page, page.getByRole('textbox', { name: 'Пароль', exact: true }), password);
  await button(page, 'Войти').click();
  await expect(page.getByRole('tab', { name: 'Теория', exact: true })).toBeVisible();
  await skipCoach(page);
  await expect(page.locator('flt-semantics').getByText('Добро пожаловать!', { exact: true })).toHaveCount(0);
}

export async function skipCoach(page: Page): Promise<void> {
  await page.waitForTimeout(350);
  const skip = button(page, 'Пропустить');
  if (await skip.isVisible()) {
    await skip.click();
    await expect(skip).toHaveCount(0);
    await waitForCoachToast(page);
  }
}

export async function completeCoachTour(page: Page): Promise<void> {
  await expect(button(page, 'Поехали')).toBeVisible();
  await screenshot(page, 'coach-intro');
  await button(page, 'Поехали').click();
  await expect(page.getByRole('group', { name: /Открой теорию/ })).toBeVisible();
  await tab(page, 'Теория');
  await expect(page.getByRole('group', { name: /Первый урок/ })).toBeVisible();
  await lesson(page, 'L00-01').click();
  await expect(page.getByRole('group', { name: /Прочитай и иди дальше/ })).toBeVisible();
  await button(page, 'Дальше').click();
  await expect(page.getByRole('group', { name: /Выбери ответ/ })).toBeVisible();
  await button(page, 'можно спеть').click();
  await expect(page.getByRole('group', { name: /Закрепи шаг/ })).toBeVisible();
  await button(page, 'Дальше').click();
  await button(page, 'К практике').click();
  await expect(button(page, 'Понятно')).toBeVisible();
  await button(page, 'Понятно').click();
  await expect(button(page, 'Пропустить')).toHaveCount(0);
  await waitForCoachToast(page);
  await screenshot(page, 'coach-finished');
}

async function waitForCoachToast(page: Page): Promise<void> {
  const toast = page.locator('flt-semantics').getByText(
    'Маршрут пройден. Сначала теория, затем практика.', { exact: true });
  await expect(toast).toBeVisible();
  await expect(toast).toHaveCount(0);
}

export async function tab(page: Page, name: string): Promise<void> {
  await page.getByRole('tab', { name, exact: true }).click();
}

export function lesson(page: Page, id: string): Locator {
  return page.locator(`[flt-semantics-identifier="lesson-${id}"]`);
}

// Flutter's scrollable accessibility DOM only exposes laid-out children. Use
// real wheel input and keep the pointer over the content, outside the nav bar.
export async function findLesson(page: Page, id: string): Promise<Locator> {
  const target = lesson(page, id);
  return findInList(page, target, `Lesson ${id}`);
}

export async function findInList(page: Page, target: Locator, label: string): Promise<Locator> {
  const viewport = page.viewportSize();
  if (!viewport) throw new Error('The browser viewport must be fixed');
  await page.mouse.move(190, 350);
  await page.mouse.wheel(0, -100_000);
  await page.waitForTimeout(200);
  for (let i = 0; i < 110; i += 1) {
    let direction = 1;
    if (await target.count()) {
      const box = await target.boundingBox();
      if (box && box.height > 0 && box.y >= 8 && box.y + box.height <= viewport.height - 104) {
        return target;
      }
      if (box && box.y < 8) direction = -1;
    }
    // Never DOM-scroll a semantics node: Flutter's cached children can exist
    // outside the canvas viewport. Only real wheel events move the painted UI.
    await page.mouse.wheel(0, 150 * direction);
    await page.waitForTimeout(180);
  }
  throw new Error(`${label} not reachable through the visible list`);
}

export async function back(page: Page): Promise<void> {
  await page.mouse.move(190, 450);
  await page.waitForTimeout(350);
  await page.getByRole('button', { name: /^(Back|Назад)$/ })
    .or(page.getByRole('button').filter({ hasText: /Back|Назад/ })).first().click();
  await page.waitForTimeout(350);
}

export async function readProgress(page: Page, id: string): Promise<ProgressBook | null> {
  return page.evaluate((key) => {
    const raw = localStorage.getItem(key);
    if (raw === null) return null;
    const value = JSON.parse(raw) as string | object;
    return typeof value === 'string' ? JSON.parse(value) : value;
  }, progressKey(id));
}

export async function seedOnlyNoteAnchors(page: Page): Promise<void> {
  const book = JSON.parse(readFileSync(join(__dirname, '../fixtures/note_anchors_mastered.json'), 'utf8'));
  expect(book.user_id).toBe(accountA.id);
  expect(Object.keys(book.competencies)).toEqual(['not.anchors_treble']);
  expect(book.competencies['not.anchors_treble'].status).toBe('mastered');
  // SharedPreferences Web stores a JSON encoded string containing ProgressBook.
  // This is a production-serialized fixture, not an isMastered callback.
  await page.evaluate(({ key, serialized }) => {
    localStorage.setItem(key, JSON.stringify(serialized));
  }, { key: progressKey(accountA.id), serialized: JSON.stringify(book) });
}

export async function completeNoteLesson(page: Page): Promise<void> {
  await button(page, 'Дальше').click();
  // L03-04 has 8 guided choices, 4 check choices, and its transfer item.
  const answers = ['до', 'ре', 'ми', 'фа', 'соль', 'до', 'ре', 'ми',
    'до', 'до', 'до', 'до', 'до'];
  for (const answer of answers) {
    await button(page, answer).click();
    await button(page, 'Дальше').click();
  }
  await expect(page.getByText('Верно 13 из 13', { exact: true })).toBeVisible();
}

export async function completePitchLesson(page: Page): Promise<void> {
  await button(page, 'Дальше').click();
  await button(page, 'выше').click();
  await button(page, 'Дальше').click();
  await button(page, 'так же').click();
  await button(page, 'Дальше').click();
  await expect(page.getByText('Верно 2 из 2', { exact: true })).toBeVisible();
}

export async function completeFreshToneLesson(page: Page): Promise<void> {
  await button(page, 'Дальше').click();
  for (const answer of ['можно спеть', 'нельзя спеть', 'нельзя спеть',
    'можно спеть', 'можно спеть', 'нельзя спеть', 'можно спеть',
    'нельзя спеть', 'можно спеть', 'нельзя спеть']) {
    await button(page, answer).click();
    await button(page, 'Дальше').click();
  }
  for (const answer of ['фортепиано', 'голос', 'флейта']) {
    const option = page.getByRole('checkbox', { name: answer, exact: true });
    await option.click();
    await expect(option).toBeChecked();
  }
  await button(page, 'Проверить').click();
  await button(page, 'Дальше').click();
  await expect(page.getByText('Верно 11 из 11', { exact: true })).toBeVisible();
}

export async function screenshot(page: Page, name: string): Promise<void> {
  // Flutter animations render into a canvas, so wait for route transitions too.
  // toHaveScreenshot subsequently requires two stable frames and saves the
  // expected/actual/diff PNGs in Playwright's normal failure artifacts.
  await page.mouse.move(0, 0);
  await page.waitForTimeout(350);
  await expect(page.locator('flt-semantics').getByText(
    /^(Маршрут пройден\. Сначала теория, затем практика\.|Добро пожаловать!|Пароль обновлён|Аккаунт создан\. Добро пожаловать!)$/,
  )).toHaveCount(0);
  await expect(page).toHaveScreenshot(`${name}.png`);
}
