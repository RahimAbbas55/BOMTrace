const AppError = require('../utils/AppError');
const { verifyToken } = require('../utils/token');

// expects "Authorization: Bearer <token>", sets req.user = { id, role }
function authenticate(req, res, next) {
  const header = req.get('Authorization') || '';
  const [scheme, token] = header.split(' ');

  if (scheme !== 'Bearer' || !token) {
    return next(new AppError('Authentication required', 401));
  }

  try {
    req.user = verifyToken(token);
  } catch (err) {
    return next(err);
  }
  return next();
}

module.exports = authenticate;