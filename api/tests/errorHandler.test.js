// the handler only needs nodeEnv, so these tests need neither .env nor a database
jest.mock('../src/config/env', () => ({ nodeEnv: 'test' }));

const env = require('../src/config/env');
const errorHandler = require('../src/middlewares/errorHandler');
const AppError = require('../src/utils/AppError');

function fakeRes() {
  const res = {};
  res.status = jest.fn().mockReturnValue(res);
  res.json = jest.fn().mockReturnValue(res);
  return res;
}

beforeEach(() => {
  env.nodeEnv = 'test';
  jest.spyOn(console, 'log').mockImplementation(() => {});
});

afterEach(() => {
  jest.restoreAllMocks();
});

describe('errorHandler', () => {
  it('turns a package error into its HTTP status and a clean message', () => {
    const err = new Error(
      'ORA-20010: The creator cannot approve their own change order CO-2026-005\nORA-06512: at "PLM_APP.PLM_PKG", line 1'
    );
    err.errorNum = 20010;
    const res = fakeRes();

    errorHandler(err, {}, res, jest.fn());

    expect(res.status).toHaveBeenCalledWith(403);
    expect(res.json).toHaveBeenCalledWith({
      status: 'error',
      message: 'The creator cannot approve their own change order CO-2026-005',
    });
  });

  it('turns a constraint error into a safe message', () => {
    const err = new Error('ORA-00001: unique constraint (PLM_APP.UQ_ITEMS_NUMBER) violated');
    err.errorNum = 1;
    const res = fakeRes();

    errorHandler(err, {}, res, jest.fn());

    expect(res.status).toHaveBeenCalledWith(409);
    expect(res.json).toHaveBeenCalledWith({
      status: 'error',
      message: 'A record with the same unique value already exists',
    });
  });

  it('turns a malformed JSON body into a 400', () => {
    const err = Object.assign(new Error('Unexpected token'), { type: 'entity.parse.failed' });
    const res = fakeRes();

    errorHandler(err, {}, res, jest.fn());

    expect(res.status).toHaveBeenCalledWith(400);
    expect(res.json).toHaveBeenCalledWith({ status: 'error', message: 'Invalid JSON body' });
  });

  it('keeps the status of an AppError', () => {
    const res = fakeRes();

    errorHandler(new AppError('Missing', 404), {}, res, jest.fn());

    expect(res.status).toHaveBeenCalledWith(404);
    expect(res.json).toHaveBeenCalledWith({ status: 'error', message: 'Missing' });
  });

  it('shows the message of an unknown error outside production', () => {
    const res = fakeRes();

    errorHandler(new Error('boom'), {}, res, jest.fn());

    expect(res.status).toHaveBeenCalledWith(500);
    expect(res.json).toHaveBeenCalledWith({ status: 'error', message: 'boom' });
  });

  it('hides the message of an unknown error in production', () => {
    env.nodeEnv = 'production';
    const res = fakeRes();

    errorHandler(new Error('boom'), {}, res, jest.fn());

    expect(res.status).toHaveBeenCalledWith(500);
    expect(res.json).toHaveBeenCalledWith({ status: 'error', message: 'Internal Server Error' });
  });
});