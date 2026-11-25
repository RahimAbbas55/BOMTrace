const request = require('supertest');
const app = require('../src/app');
const { initPool, closePool } = require('../src/config/db');

beforeAll(async () => {
  await initPool();
});

afterAll(async () => {
  await closePool();
});

describe('GET /api/health', () => {
  it('reports the API and the database as up', async () => {
    const res = await request(app).get('/api/health');

    expect(res.status).toBe(200);
    expect(res.body).toEqual({ status: 'ok', db: 'up' });
  });
});

describe('error handling', () => {
  it('returns a JSON 404 for an unknown route', async () => {
    const res = await request(app).get('/api/nope');

    expect(res.status).toBe(404);
    expect(res.body).toEqual({
      status: 'error',
      message: 'Route not found: GET /api/nope',
    });
  });

  it('returns a JSON 400 for a malformed JSON body', async () => {
    const res = await request(app)
      .post('/api/health')
      .set('Content-Type', 'application/json')
      .send('{bad');

    expect(res.status).toBe(400);
    expect(res.body).toEqual({ status: 'error', message: 'Invalid JSON body' });
  });

  it('does not leak a stack trace', async () => {
    const res = await request(app).get('/api/nope');

    expect(res.body).not.toHaveProperty('stack');
  });
});