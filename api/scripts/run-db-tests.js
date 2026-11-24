// runs every db/tests/*.sql file against the database and reports the PASS and FAIL lines
// usage: npm run test:db (from api/), needs the same .env as the API
const fs = require('fs');
const path = require('path');
const oracledb = require('oracledb');
const { initPool, withConnection, closePool } = require('../src/config/db');

const testDir = path.resolve(__dirname, '../../db/tests');

// the files are written for the SQL worksheet, drop what only a worksheet understands
function toPlsqlBlock(text) {
  return text
    .split('\n')
    .filter((line) => !/^\s*SET\s+SERVEROUTPUT/i.test(line))
    .join('\n')
    .trim()
    .replace(/\n\/\s*$/, '');
}

// reads everything the block printed with DBMS_OUTPUT
async function readOutput(conn) {
  const lines = [];
  for (;;) {
    const result = await conn.execute(
      'BEGIN DBMS_OUTPUT.GET_LINE(:line, :status); END;',
      {
        line: { dir: oracledb.BIND_OUT, type: oracledb.STRING, maxSize: 32767 },
        status: { dir: oracledb.BIND_OUT, type: oracledb.NUMBER },
      }
    );
    if (result.outBinds.status !== 0) break;
    lines.push(result.outBinds.line);
  }
  return lines;
}

async function runFile(conn, file) {
  const block = toPlsqlBlock(fs.readFileSync(path.join(testDir, file), 'utf8'));

  await conn.execute('BEGIN DBMS_OUTPUT.ENABLE(1000000); END;');

  let error = null;
  try {
    await conn.execute(block);
  } catch (err) {
    error = err.message;
  }

  const lines = await readOutput(conn);
  return {
    file,
    pass: lines.filter((line) => line.startsWith('PASS')).length,
    failed: lines.filter((line) => line.startsWith('FAIL')),
    error,
  };
}

async function main() {
  const files = fs
    .readdirSync(testDir)
    .filter((file) => file.endsWith('.sql'))
    .sort();

  await initPool();

  let totalPass = 0;
  let problems = 0;

  for (const file of files) {
    const result = await withConnection(async (conn) => {
      try {
        return await runFile(conn, file);
      } finally {
        // a test that stopped on an error never reached its own rollback
        await conn.rollback();
        await conn.execute('BEGIN plm_audit.clear_user; END;');
      }
    });

    totalPass += result.pass;
    const broken = result.failed.length > 0 || result.error || result.pass === 0;
    if (broken) problems += 1;

    console.log(`${broken ? 'FAIL' : 'ok  '} ${file}  ${result.pass} passed`);
    result.failed.forEach((line) => console.log(`       ${line}`));
    if (result.error) console.log(`       ${result.error}`);
    if (!result.error && result.pass === 0 && result.failed.length === 0) {
      console.log('       no PASS lines, the test printed nothing');
    }
  }

  console.log(`\n${files.length} files, ${totalPass} checks passed, ${problems} files with problems`);
  await closePool();
  process.exit(problems > 0 ? 1 : 0);
}

main().catch((err) => {
  console.error('Test run failed:', err.message);
  process.exit(1);
});