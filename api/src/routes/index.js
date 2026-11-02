const express = require('express');
const healthRoutes = require('./health.routes');

// Initialize the router
const router = express.Router();

// Using the routes
router.use('/health' , healthRoutes);

// Exporting routes
module.exports = router;