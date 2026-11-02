const app = require('./app');
const env = require('./config/env');
const { initPool, closePool } = require('./config/db');
const port = process.env.PORT || 3000;

async function start() {
    await initPool();
    console.log('Oracle pool ready!');

    const server = app.listen(env.port, () => {
        console.log(`BOMTrace API listening on :${env.port}`);
    });

    // closing pool proeperly on shutdown
    const shutdown = async () => {
        server.close();
        await closePool();
        process.exit(0);
    }
    process.on('SIGINT', shutdown);
    process.on('SIGTERM', shutdown);
}

start().catch((err) => {
    console.error('Startup failed:', err);
    process.exit(1);
});