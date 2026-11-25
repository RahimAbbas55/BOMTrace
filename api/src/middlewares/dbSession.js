const { acquireConnection } = require('../config/db');
const AppError = require('../utils/AppError');

// Gives every request its own database connection as req.db.
// Transaction rule: models never commit, the controller calls req.db.commit() once at the end.
// Whatever is not committed is rolled back when the response closes.

// undo uncommitted work and forget the acting user, in one round trip
const cleanupSql = 'BEGIN ROLLBACK; plm_audit.clear_user; END;';

async function release(conn) {
    let broken = false;

    try {
        // a connection we could not clean must not go back into the pool
        if (broken) {
            await conn.close({ drop: true });
        } else {
            await conn.close();
        }
    } catch (err) {
        console.error('Releasing the connection failed:', err.message);
    }

    try {
        // a connection we could not clean must not go back into the pool
        await conn.close(broken ? { drop: true } : undefined);
    } catch (err) {
        console.error('Releasing the connection failed:', err.message);
    }
}

async function dbSession(req, res, next) {
    let conn;
    try {
        conn = await acquireConnection();
    } catch (err) {
        return next(new AppError('Database unavailable', 503));
    }

    req.db = conn;

    // close fires after the response was sent, or when the client went away
    res.once('close', () => release(conn));

    return next();
}

module.exports = dbSession;