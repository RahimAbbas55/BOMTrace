jest.mock('../src/config/db', () => ({ acquireConnection: jest.fn() }));

const { EventEmitter } = require('events');
const { acquireConnection } = require('../src/config/db');
const dbSession = require('../src/middlewares/dbSession');
const AppError = require('../src/utils/AppError');

function fakeConn() {
  return {
    execute: jest.fn().mockResolvedValue({}),
    close: jest.fn().mockResolvedValue(),
  };
}

// lets the pending promise callbacks run
const flush = () => new Promise((resolve) => setImmediate(resolve));

beforeEach(() => {
  acquireConnection.mockReset();
  jest.spyOn(console, 'error').mockImplementation(() => {});
});

afterEach(() => {
  console.error.mockRestore();
});

describe('dbSession', () => {
  it('attaches a connection to the request and continues', async () => {
    const conn = fakeConn();
    acquireConnection.mockResolvedValue(conn);
    const req = {};
    const next = jest.fn();

    await dbSession(req, new EventEmitter(), next);

    expect(req.db).toBe(conn);
    expect(next).toHaveBeenCalledWith();
  });

  it('rolls back, clears the audit user and releases the connection when the response closes', async () => {
    const conn = fakeConn();
    acquireConnection.mockResolvedValue(conn);
    const res = new EventEmitter();

    await dbSession({}, res, jest.fn());
    res.emit('close');
    await flush();

    expect(conn.execute).toHaveBeenCalledTimes(1);
    const sql = conn.execute.mock.calls[0][0];
    expect(sql).toContain('ROLLBACK');
    expect(sql).toContain('plm_audit.clear_user');
    expect(conn.close).toHaveBeenCalledTimes(1);
    // no argument at all, the driver rejects an explicit undefined
    expect(conn.close.mock.calls[0]).toEqual([]);
  });

  it('releases the connection only once', async () => {
    const conn = fakeConn();
    acquireConnection.mockResolvedValue(conn);
    const res = new EventEmitter();

    await dbSession({}, res, jest.fn());
    res.emit('close');
    res.emit('close');
    await flush();

    expect(conn.close).toHaveBeenCalledTimes(1);
  });

  it('answers 503 when no connection can be acquired', async () => {
    acquireConnection.mockRejectedValue(new Error('pool closed'));
    const req = {};
    const next = jest.fn();

    await dbSession(req, new EventEmitter(), next);

    expect(next).toHaveBeenCalledTimes(1);
    const err = next.mock.calls[0][0];
    expect(err).toBeInstanceOf(AppError);
    expect(err.statusCode).toBe(503);
    expect(req.db).toBeUndefined();
  });

  it('drops the connection when the cleanup fails', async () => {
    const conn = fakeConn();
    conn.execute.mockRejectedValue(new Error('session broken'));
    acquireConnection.mockResolvedValue(conn);
    const res = new EventEmitter();

    await dbSession({}, res, jest.fn());
    res.emit('close');
    await flush();

    expect(conn.close).toHaveBeenCalledWith({ drop: true });
  });
});