const jwt = require('jsonwebtoken');
const env = require('../config/env');
const AppError = require('./AppError');

// the token carries the user id as subject and the role, nothing else
function signToken(user) {
  return jwt.sign({ role: user.role }, env.jwt.secret, {
    algorithm: 'HS256',
    subject: String(user.id),
    expiresIn: env.jwt.expiresIn,
  });
}

// returns { id, role }, every failure is the same 401 so callers learn nothing
function verifyToken(token) {
  try {
    const payload = jwt.verify(token, env.jwt.secret, { algorithms: ['HS256'] });
    return { id: Number(payload.sub), role: payload.role };
  } catch (err) {
    throw new AppError('Invalid or expired token', 401);
  }
}

module.exports = { signToken, verifyToken };