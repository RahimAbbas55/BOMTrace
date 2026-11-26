jest.mock('../src/config/env', () => ({
  nodeEnv: 'test',
  jwt: { secret: 'a'.repeat(40), expiresIn: '1h' },
}));

const authenticate = require('../src/middlewares/authenticate');
const requireRole = require('../src/middlewares/requireRole');
const auditUser = require('../src/middlewares/auditUser');
const { signToken } = require('../src/utils/token');

const flush = () => new Promise((resolve) => setImmediate(resolve));

function reqWithHeader(value) {
  return { get: (name) => (name.toLowerCase() === 'authorization' ? value : undefined) };
}

describe('authenticate', () => {
  it('rejects a request without a header', () => {
    const next = jest.fn();
    authenticate(reqWithHeader(undefined), {}, next);

    expect(next.mock.calls[0][0].statusCode).toBe(401);
  });

  it('rejects a scheme that is not Bearer', () => {
    const next = jest.fn();
    authenticate(reqWithHeader('Basic abc'), {}, next);

    expect(next.mock.calls[0][0].statusCode).toBe(401);
  });

  it('rejects an invalid token', () => {
    const next = jest.fn();
    authenticate(reqWithHeader('Bearer nonsense'), {}, next);

    expect(next.mock.calls[0][0].statusCode).toBe(401);
  });

  it('sets req.user for a valid token and continues', () => {
    const req = reqWithHeader(`Bearer ${signToken({ id: 3, role: 'ENGINEER' })}`);
    const next = jest.fn();
    authenticate(req, {}, next);

    expect(req.user).toEqual({ id: 3, role: 'ENGINEER' });
    expect(next).toHaveBeenCalledWith();
  });
});

describe('requireRole', () => {
  it('lets a listed role through', () => {
    const next = jest.fn();
    requireRole('APPROVER')({ user: { role: 'APPROVER' } }, {}, next);

    expect(next).toHaveBeenCalledWith();
  });

  it('answers 403 for another role', () => {
    const next = jest.fn();
    requireRole('APPROVER')({ user: { role: 'ENGINEER' } }, {}, next);

    expect(next.mock.calls[0][0].statusCode).toBe(403);
  });

  it('answers 401 when nobody is authenticated', () => {
    const next = jest.fn();
    requireRole('APPROVER')({}, {}, next);

    expect(next.mock.calls[0][0].statusCode).toBe(401);
  });
});

describe('auditUser', () => {
  it('sets the acting user on the request connection', async () => {
    const execute = jest.fn().mockResolvedValue({});
    const next = jest.fn();

    auditUser({ db: { execute }, user: { id: 5 } }, {}, next);
    await flush();

    expect(execute).toHaveBeenCalledWith('BEGIN plm_audit.set_user(:id); END;', { id: 5 });
    expect(next).toHaveBeenCalledWith();
  });

  it('passes a database failure to the error handler', async () => {
    const failure = new Error('database down');
    const execute = jest.fn().mockRejectedValue(failure);
    const next = jest.fn();

    auditUser({ db: { execute }, user: { id: 5 } }, {}, next);
    await flush();

    expect(next).toHaveBeenCalledWith(failure);
  });
});