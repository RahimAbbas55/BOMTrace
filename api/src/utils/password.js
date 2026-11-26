const bcrypt = require('bcryptjs');
const COST = 10;    // cost 10 matches the hash in the seed data
function hashPassword(plain){
    return bcrypt.hash(plain , COST);
}
function verifyPassword(plain , hash){
    return bcrypt.compare(plain , hash);
}
module.exports = { hashPassword , verifyPassword };