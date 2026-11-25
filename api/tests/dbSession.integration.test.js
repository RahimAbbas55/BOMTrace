const express = require('express');
const request = require('supertest');
const dbSession = require('../src/middlewares/dbSession');
const errorHandler = require('../src/middlewares/errorHandler');
const asyncHandler = require('../src/utils/asyncHandler');
const { initPool, closePool, withConnection } = require('../src/config/db');

const insertSql = `
  INSERT INTO items (item_number, name, item_type, created_by)
  SELECT 'TEST-SESSION', 'Left uncommitted', 'BUY', user_id
  FROM users WHERE email = 'engineer@bomtrace.dev'`;

// a small app: one route that changes data and never commits, one that fails
function buildApp() {
  const app = express();

  app.post('/leave-open', dbSession, asyncHandler(async (req, res) => {
    await req.db.execute(insertSql);
    res.json({ status: 'ok' });
  }));

  app.get('/fails', dbSession, asyncHandler(async (req) => {
    await req.db.execute('SELECT * FROM table_that_does_not_exist');
  }));

  app.use(errorHandler);
  return app;
}

beforeAll(async () => {
  await initPool();
});

afterAll(async () => {
  await closePool();
});

describe('dbSession with a real database', () => {
  it('does not keep work that was not committed', async () => {
    const res = await request(buildApp()).post('/leave-open');
    expect(res.status).toBe(200);

    // the open insert holds a lock on the unique item number,
    // this second insert only gets through once the first session rolled back
    const count = await withConnection(async (conn) => {
      await conn.execute(insertSql);
      await conn.rollback();
      const result = await conn.execute(
        "SELECT COUNT(*) AS N FROM items WHERE item_number = 'TEST-SESSION'"
      );
      return result.rows[0].N;
    });

    expect(count).toBe(0);
  });

  it('gives connections back even when requests fail', async () => {
    jest.spyOn(console, 'log').mockImplementation(() => {});
    const app = buildApp();

    // more failures than the pool has connections, a leak would show up as a 503
    for (let i = 0; i < 8; i += 1) {
      const res = await request(app).get('/fails');
      expect(res.status).toBe(500);
    }

    console.log.mockRestore();
  });
});