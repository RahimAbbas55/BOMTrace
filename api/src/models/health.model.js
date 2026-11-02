const { withConnection } = require('../config/db');
// cheapest possible query that proves the database is reachable
async function ping(){
    return withConnection((conn) => conn.execute('SELECT 1 from dual'));
}
module.exports = { ping };