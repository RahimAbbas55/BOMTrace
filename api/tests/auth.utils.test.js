jest.mock('../src/config/env', () => ({
  nodeEnv: 'test',
  jwt: { secret: 'a'.repeat(40), expiresIn: '1h' },
}));

const jwt = require('jsonwebtoken');
const { hashPassword, verifyPassword } = require('../src/utils/password');
const { signToken, verifyToken } = require('../src/utils/token');

// the engineer hash from db/seed/01_seed_users_items.sql
const seedHash = '$2b$10$/e18UaE8.i2DXVgoQngBtuqjp6ymfy2oVXoxnEq2Zxqy.SMbd8mru';

describe('password', () => {
  it('hashes and verifies', async () => {
    const hash = await hashPassword('correct horse');

    expect(hash).not.toBe('correct horse');
    expect(await verifyPassword('correct horse', hash)).toBe(true);
  });

  it('rejects a wrong password', async () => {
    const hash = await hashPassword('correct horse');

    expect(await verifyPassword('wrong horse', hash)).toBe(false);
  });

  it('gives a different hash each time', async () => {
    expect(await hashPassword('same')).not.toBe(await hashPassword('same'));
  });

  it('verifies the seeded demo login', async () => {
    expect(await verifyPassword('BomTrace-Eng-2026', seedHash)).toBe(true);
  });
});

describe('token', () => {
  it('round trips the id and role', () => {
    const user = verifyToken(signToken({ id: 7, role: 'APPROVER' }));

    expect(user).toEqual({ id: 7, role: 'APPROVER' });
  });

  it('rejects a token signed with another secret', () => {
    const forged = jwt.sign({ role: 'APPROVER' }, 'b'.repeat(40), { subject: '1' });

    expect(() => verifyToken(forged)).toThrow('Invalid or expired token');
  });

  it('rejects an expired token', () => {
    const expired = jwt.sign({ role: 'ENGINEER' }, 'a'.repeat(40), { subject: '1', expiresIn: -10 });

    expect(() => verifyToken(expired)).toThrow('Invalid or expired token');
  });

  it('rejects a token that claims no signature', () => {
    const unsigned = jwt.sign({ role: 'APPROVER' }, '', { algorithm: 'none', subject: '1' });

    expect(() => verifyToken(unsigned)).toThrow('Invalid or expired token');
  });

  it('rejects garbage and reports 401', () => {
    try {
      verifyToken('not-a-token');
      throw new Error('should have thrown');
    } catch (err) {
      expect(err.statusCode).toBe(401);
    }
  });
});