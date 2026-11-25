const { mapOracleError } = require('../src/utils/oracleErrors');
const AppError = require('../src/utils/AppError');

// builds an error shaped like the ones node-oracledb throws
function oracleError(code, text) {
  const err = new Error(
    `ORA-${String(code).padStart(5, '0')}: ${text}\nORA-06512: at "PLM_APP.PLM_PKG", line 10`
  );
  err.errorNum = code;
  return err;
}

describe('PLM_PKG errors', () => {
  const expected = {
    20001: 404, 20002: 409, 20003: 409, 20004: 409,
    20005: 404, 20006: 409, 20007: 422, 20008: 404,
    20009: 403, 20010: 403, 20011: 400, 20012: 422,
    20013: 404, 20014: 400, 20015: 409, 20016: 400,
  };

  it.each(Object.entries(expected))('maps ORA-%s to HTTP %s', (code, status) => {
    const mapped = mapOracleError(oracleError(Number(code), 'Something went wrong'));

    expect(mapped).toBeInstanceOf(AppError);
    expect(mapped.statusCode).toBe(status);
  });

  it('keeps only the readable first line of the message', () => {
    const mapped = mapOracleError(
      oracleError(20006, 'Change order CO-2026-002 cannot move from APPROVED to SUBMITTED')
    );

    expect(mapped.message).toBe('Change order CO-2026-002 cannot move from APPROVED to SUBMITTED');
  });

  it('reads the code from the message when errorNum is missing', () => {
    const err = new Error('ORA-20005: Change order not found: 99');
    const mapped = mapOracleError(err);

    expect(mapped.statusCode).toBe(404);
    expect(mapped.message).toBe('Change order not found: 99');
  });
});

describe('data errors', () => {
  const expected = { 1: 409, 1400: 400, 1722: 400, 2290: 400, 2291: 409, 2292: 409, 12899: 400 };

  it.each(Object.entries(expected))('maps ORA-%s to HTTP %s', (code, status) => {
    const mapped = mapOracleError(oracleError(Number(code), 'raw Oracle text'));

    expect(mapped.statusCode).toBe(status);
  });

  it('does not leak the constraint name', () => {
    const err = oracleError(1, 'unique constraint (PLM_APP.UQ_ITEMS_NUMBER) violated');
    const mapped = mapOracleError(err);

    expect(mapped.message).not.toContain('UQ_ITEMS_NUMBER');
    expect(mapped.message).not.toContain('PLM_APP');
  });
});

describe('other errors', () => {
  it('returns null for an Oracle error we do not map', () => {
    expect(mapOracleError(oracleError(1403, 'no data found'))).toBeNull();
  });

  it('returns null for a plain error', () => {
    expect(mapOracleError(new Error('boom'))).toBeNull();
  });

  it('returns null for a driver error', () => {
    expect(mapOracleError(new Error('NJS-040: connection request timeout'))).toBeNull();
  });

  it('returns null for an AppError', () => {
    expect(mapOracleError(new AppError('Not here', 404))).toBeNull();
  });
});