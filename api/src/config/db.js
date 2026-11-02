const path = require('path');
const oracledb = require('oracledb');
const env = require('./env');

// return rows as objects instead of arrays
oracledb.outFormat = oracledb.OUT_FORMAT_OBJECT;

let pool;

async function initPool() {
  const walletDir = path.resolve(env.db.walletDir);

  pool = await oracledb.createPool({
    user: env.db.user,
    password: env.db.password,
    connectString: env.db.connectString,
    configDir: walletDir,
    walletLocation: walletDir,
    walletPassword: env.db.walletPassword,
    poolMin: 1,
    poolMax: 5,
    poolIncrement: 1,
  });
}

// borrow a connection and always release it
async function withConnection(fn) {
  const conn = await pool.getConnection();
  try {
    return await fn(conn);
  } finally {
    await conn.close();
  }
}

async function closePool() {
  if (pool) await pool.close(10);
}

module.exports = { initPool, withConnection, closePool };