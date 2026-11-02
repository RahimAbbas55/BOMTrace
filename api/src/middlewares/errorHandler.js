const env = require('../config/env');
const AppError = require('../utils/AppError');

function errorHandler(err , req , res , next){
    // express.json() throws json error
    if (err.type === 'entity.parse.failed') {
        err = new AppError('Invalid JSON body', 400);
    }
    const status = err.statusCode || 500;
    // log server faults only
    if (status >= 500) console.log(err);
    // If production environment, then show meaningful error messages instead of leaking internal errors
    const message = status === 500 && env.nodeEnv === 'production' ? 'Internal Server Error' : err.message;

    res.status(status).json({
        status : 'error',
        message
    });
}

module.exports = errorHandler;