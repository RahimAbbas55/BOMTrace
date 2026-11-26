const express = require('express');
const request = require('supertest');
const { protect } = require('../src/middlewares');
const errorHandler = require('../src/middlewares/errorHandler');
const asyncHandler = require('../src/utils/asyncHandler');
const { signToken } = require('../src/utils/token');
const { initPool, closePool, withConnection } = require('../src/config/db');

let engineer;
let approver;

function buildApp() {
  const app = express();

  // reports the acting user as the database sees it, on the request connection
  app.get('/whoami', ...protect(), asyncHandler(async (req, res) => {
    const result = await req.db.execute('SELECT plm_audit.get_user AS ID FROM dual');
    res.json({ auditUser: result.rows[0].ID });
  }));

  app.get('/approvers-only', ...protect('APPROVER'), (req, res) => {
    res.json({ status: 'ok' });
  });

  app.use(errorHandler);
  return app;
}

beforeAll(async () => {
  await initPool();
  const users = await withConnection((conn) =>
    conn.execute('SELECT user_id, role FROM users WHERE email IN (:a, :b)', {
      a: 'engineer@bomtrace.dev',
      b: 'approver@bomtrace.dev',
    })
  );
  engineer = users.rows.find((row) => row.ROLE === 'ENGINEER').USER_ID;
  approver = users.rows.find((row) => row.ROLE === 'APPROVER').USER_ID;
});

afterAll(async () => {
  await closePool();
});

describe('protected routes with a real database', () => {
  it('rejects a request without a token', async () => {
    const res = await request(buildApp()).get('/whoami');

    expect(res.status).toBe(401);
  });

  it('sets the acting user on the request connection', async () => {
    const token = signToken({ id: engineer, role: 'ENGINEER' });
    const res = await request(buildApp()).get('/whoami').set('Authorization', `Bearer ${token}`);

    expect(res.status).toBe(200);
    expect(res.body.auditUser).toBe(engineer);
  });

  it('forgets the acting user once the request is over', async () => {
    const token = signToken({ id: engineer, role: 'ENGINEER' });
    await request(buildApp()).get('/whoami').set('Authorization', `Bearer ${token}`);

    const result = await withConnection((conn) =>
      conn.execute('SELECT plm_audit.get_user AS ID FROM dual')
    );

    expect(result.rows[0].ID).toBeNull();
  });

  it('keeps an engineer out of an approver route', async () => {
    const token = signToken({ id: engineer, role: 'ENGINEER' });
    const res = await request(buildApp()).get('/approvers-only').set('Authorization', `Bearer ${token}`);

    expect(res.status).toBe(403);
  });

  it('lets an approver in', async () => {
    const token = signToken({ id: approver, role: 'APPROVER' });
    const res = await request(buildApp()).get('/approvers-only').set('Authorization', `Bearer ${token}`);

    expect(res.status).toBe(200);
  });
});