// installs the PL/SQL objects from db/plsql into the database and prints any compile errors
// usage: npm run db:plsql (from api/), needs the same .env as the API
const fs = require('fs');
const path = require('path');
const { initPool, withConnection, closePool } = require('../src/config/db');

const plsqlDir = path.resolve(__dirname, '../../db/plsql');

// order matters, the triggers call plm_audit
const files = ['plm_audit.sql', 'plm_pkg.sql', 'audit_triggers.sql'];

// a statement ends at a line holding only a slash, the same rule the SQL worksheet uses
function splitStatements(text) {
  return text
    .split(/^[ \t]*\/[ \t]*$/m)
    .map((part) => part.replace(/^(\s*--[^\n]*\n)+/, '').trim())
    .filter((part) => part.length > 0);
}

async function main() {
  await initPool();
  let problems = 0;

  await withConnection(async (conn) => {
    for (const file of files) {
      const statements = splitStatements(fs.readFileSync(path.join(plsqlDir, file), 'utf8'));
      for (const statement of statements) {
        try {
          await conn.execute(statement);
        } catch (err) {
          problems += 1;
          console.log(`FAIL ${file}: ${err.message}`);
          console.log(`     in: ${statement.split('\n')[0]}`);
        }
      }
      console.log(`ran  ${file} (${statements.length} statements)`);
    }

    // creating an object with compile errors does not raise, so ask the data dictionary
    const errors = await conn.execute(
      'SELECT name, type, line, position, text FROM user_errors ORDER BY name, type, sequence'
    );
    errors.rows.forEach((row) => {
      problems += 1;
      console.log(`ERR  ${row.NAME} ${row.TYPE} line ${row.LINE}:${row.POSITION} ${row.TEXT}`);
    });

    const invalid = await conn.execute(
      "SELECT object_name, object_type FROM user_objects WHERE status = 'INVALID' ORDER BY object_name"
    );
    invalid.rows.forEach((row) => {
      console.log(`INVALID ${row.OBJECT_TYPE} ${row.OBJECT_NAME}`);
    });

    const procs = await conn.execute(
      "SELECT COUNT(DISTINCT procedure_name) AS n FROM user_procedures WHERE object_name = 'PLM_PKG' AND procedure_name IS NOT NULL"
    );
    const triggers = await conn.execute(
      "SELECT COUNT(*) AS n FROM user_triggers WHERE status = 'ENABLED'"
    );
    console.log(`\nPLM_PKG has ${procs.rows[0].N} public procedures and functions (expected 13)`);
    console.log(`${triggers.rows[0].N} enabled triggers (expected 3)`);
  });

  await closePool();
  process.exit(problems > 0 ? 1 : 0);
}

main().catch((err) => {
  console.error('Install failed:', err.message);
  process.exit(1);
});