const express = require('express');
const app = express();
app.use(express.json());

// Health check - add db check later
app.get('/api/health' , (req , res) => {
    res.json({
        'status' : 'ok',
        'message' : 'Health check successful!',
    })
});

module.exports = app;