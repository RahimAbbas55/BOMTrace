const express = require('express');
const healthController = require('../controllers/health.controller');

// Initialize the router
const router = express.Router();

// GET Routes
router.get('/' , healthController.getHealth);

// Exporting the routes
module.exports = router;