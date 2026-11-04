import { PGlite } from '@electric-sql/pglite';
import { readFile, readdir } from 'node:fs/promises';
import { resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

// Deliberately no connection string/remote mode: fixtures cannot touch user data.
const root = resolve(dirname(fileURLToPath(import.meta.url)), '../..');
const mutation = process.argv.slice(2);
if (mutation.some(arg => arg !== '--mutation-test')) throw new Error('Usage: node tool/database/verify.mjs [--mutation-test]');
const migrations = (await readdir(resolve(root, 'supabase/migrations'))).filter(f => f.endsWith('.sql')).sort();
const tests = (await readdir(resolve(root, 'supabase/tests'))).filter(f => f.endsWith('_test.sql')).sort();
if (!migrations.length || !tests.length) throw new Error('Migration and SQL test files are required.');
async function open() {
  const db = await PGlite.create();
  await db.exec(await readFile(new URL('bootstrap.sql', import.meta.url), 'utf8'));
  await db.exec(await readFile(resolve(root, 'supabase/schema.sql'), 'utf8'));
  for (const migration of migrations) {
    const sql = await readFile(resolve(root, 'supabase/migrations', migration), 'utf8');
    await db.exec(sql);
    await db.exec(sql); // Applying an existing migration must preserve data and succeed.
  }
  return db;
}
async function run(db) {
  let count = 0;
  for (const file of tests) {
    const results = await db.exec(await readFile(resolve(root, 'supabase/tests', file), 'utf8'));
    const assertions = results.flatMap(r => r.rows ?? []).filter(r => typeof r.check === 'string');
    if (!assertions.length) throw new Error(`No assertions ran in ${file}`);
    count += assertions.length;
    console.log(`${file}: ${assertions.length} SQL assertions passed`);
  }
  return count;
}
let db = await open();
try {
  const count = await run(db);
  console.log(`PostgreSQL/RLS: ${count} assertions passed; migrations apply twice. Isolated PGlite PostgreSQL, hosted deployment not established.`);
} finally { await db.close(); }
if (mutation.includes('--mutation-test')) {
  for (const table of ['ai_chat_messages', 'practice_books', 'user_progress']) {
    db = await open();
    try {
      const exists = (await db.query('select to_regclass($1) as name', [`public.${table}`])).rows[0]?.name;
      if (!exists) continue;
      await db.exec(`create policy intentionally_insecure_test on public.${table} for select to authenticated using (true)`);
      let detected = false;
      try { await run(db); } catch (error) {
        if (String(error.message).startsWith('assertion failed:')) detected = true;
        else throw error;
      }
      if (!detected) throw new Error(`Broad SELECT policy on ${table} was not detected`);
      console.log(`Negative control ${table}: insecure policy detected`);
    } finally { await db.close(); }
  }
}
