const AppError = require('../utils/AppError');

// Allow only listed roles, after authenticate
function requireRole (...roles) {
    return (req, res, next) => {
        if (!req.user){
            return next(new AppError("Authentication Required!" , 401));
        } 
        if (!roles.includes(req.user.role)){
            return next(new AppError('You do not have permission to do this', 403));
        }
        return next();
    };
}

module.exports = requireRole;