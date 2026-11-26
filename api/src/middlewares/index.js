const authenticate = require('./authenticate');
const requireRole = require('./requireRole');
const dbSession = require('./dbSession');
const auditUser = require('./auditUser');

// the full chain for a protected route, spread it into the route:
//   router.post('/x', ...protect('APPROVER'), handler)
// the role check runs before a database connection is taken
function protect(...roles) {
  const chain = [authenticate];
  if (roles.length > 0) chain.push(requireRole(...roles));
  chain.push(dbSession, auditUser);
  return chain;
}

module.exports = { protect };