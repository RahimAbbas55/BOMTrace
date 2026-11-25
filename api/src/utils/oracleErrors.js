const AppError = require('./AppError');

// PLM_PKG error codes and their HTTP status, see docs/error-codes.md
const packageErrors = {
  20001: 404, 20002: 409, 20003: 409, 20004: 409,
  20005: 404, 20006: 409, 20007: 422, 20008: 404,
  20009: 403, 20010: 403, 20011: 400, 20012: 422,
  20013: 404, 20014: 400, 20015: 409, 20016: 400,
};

// constraint and data errors, Oracle's text names internal objects so we send our own
const dataErrors = {
  1: [409, 'A record with the same unique value already exists'],
  1400: [400, 'A required value is missing'],
  1722: [400, 'A value is not a valid number'],
  2290: [400, 'A value breaks a data rule'],
  2291: [409, 'A referenced record does not exist'],
  2292: [409, 'The record is still used by other records'],
  12899: [400, 'A value is too long'],
};

// the ORA number, from the driver when it has it, otherwise from the message
function oracleCode(err) {
  if (Number.isInteger(err.errorNum)) return err.errorNum;
  const match = /ORA-(\d{5})/.exec(err.message || '');
  return match ? Number(match[1]) : null;
}

// keeps the first line and drops the ORA-200xx prefix and the ORA-06512 trace lines
function cleanMessage(message) {
  return message.split('\n')[0].replace(/^ORA-\d{5}:\s*/, '').trim();
}

// returns an AppError for errors we know, null for everything else
function mapOracleError(err) {
  const code = oracleCode(err);
  if (code === null) return null;

  if (packageErrors[code]) {
    return new AppError(cleanMessage(err.message), packageErrors[code]);
  }
  if (dataErrors[code]) {
    const [status, message] = dataErrors[code];
    return new AppError(message, status);
  }
  return null;
}

module.exports = { mapOracleError };