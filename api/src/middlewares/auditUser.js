const asyncHandler = require('../utils/asyncHandler');

// tells Oracle who is acting, on the connection this request already holds
module.exports = asyncHandler(async (req, res, next) => {
  await req.db.execute('BEGIN plm_audit.set_user(:id); END;', { id: req.user.id });
  next();
});