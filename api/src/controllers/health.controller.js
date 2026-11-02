const healthModel  = require('../models/health.model');
const asyncHandler  = require('../utils/asyncHandler');
const AppError  = require('../utils/AppError');

// GET endpoint - Health check
const getHealth = asyncHandler(async (req , res) => {
    try {
        await healthModel.ping();
    } catch (error) {
        // Database failure is due to service outage, not code error
        console.error('Health check failed:', error);
        throw new AppError('Database unavailable!' , 503);
    }
    res.json({
        status: 'ok',
        db: 'up,'
    })
});

module.exports = { getHealth };