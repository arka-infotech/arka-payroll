#!/usr/bin/env node
/**
 * Local PostgreSQL without Docker — for Arka Payroll development.
 * Keep this process running while you use the API.
 */
import EmbeddedPostgres from 'embedded-postgres';
import path from 'path';
import fs from 'fs';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const dataDir = path.join(__dirname, '..', 'backend', '.pg-data');
fs.mkdirSync(dataDir, { recursive: true });

const pg = new EmbeddedPostgres({
  databaseDir: dataDir,
  user: 'arka',
  password: 'arka_secret',
  port: 5432,
  persistent: true,
});

async function main() {
  console.log('[dev-db] Initializing embedded PostgreSQL at', dataDir);
  await pg.initialise();
  console.log('[dev-db] Starting on 127.0.0.1:5432 …');
  await pg.start();
  try {
    await pg.createDatabase('arka_payroll');
    console.log('[dev-db] Created database arka_payroll');
  } catch {
    console.log('[dev-db] Database arka_payroll already present');
  }
  console.log(
    '[dev-db] Ready → postgresql://arka:arka_secret@127.0.0.1:5432/arka_payroll',
  );
  console.log('[dev-db] Keep this terminal open. Ctrl+C to stop.');

  const shutdown = async () => {
    console.log('\n[dev-db] Stopping…');
    try {
      await pg.stop();
    } catch {
      /* ignore */
    }
    process.exit(0);
  };
  process.on('SIGINT', shutdown);
  process.on('SIGTERM', shutdown);
  await new Promise(() => {});
}

main().catch((err) => {
  console.error('[dev-db] Failed:', err);
  process.exit(1);
});
