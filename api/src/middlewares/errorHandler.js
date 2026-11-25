const env = require('../config/env');
const AppError = require('../utils/AppError');
const { mapOracleError } = require('../utils/oracleErrors');

// four arguments is how Express recognises an error middleware
function errorHandler(err, req, res, next) {
  // express.json() throws this for malformed JSON bodies
  if (err.type === 'entity.parse.failed') {
    err = new AppError('Invalid JSON body', 400);
  }

  // database errors become the matching HTTP error, anything unknown stays as it is
  const mapped = mapOracleError(err);
  if (mapped) {
    err = mapped;
  }

  const status = err.statusCode || 500;

  // log server faults only
  if (status >= 500) console.log(err);

  // never leak internals to clients in production
  const message =
    status === 500 && env.nodeEnv === 'production'
      ? 'Internal Server Error'
      : err.message;

  res.status(status).json({ status: 'error', message });
}

module.exports = errorHandler;