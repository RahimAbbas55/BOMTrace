require('dotenv').config({ quiet: true });

const required = [
  'DB_USER',
  'DB_PASSWORD',
  'DB_CONNECT_STRING',
  'DB_WALLET_DIR',
  'DB_WALLET_PASSWORD',
  'JWT_SECRET',
];

// fail fast if any required var is missing
const missing = required.filter((key) => !process.env[key]);
if (missing.length > 0) {
  throw new Error(`Missing env vars: ${missing.join(', ')}`);
}

// a short secret can be guessed, so refuse to start with one
if (process.env.JWT_SECRET.length < 32) {
  throw new Error('JWT_SECRET must be at least 32 characters');
}

module.exports = {
  port: process.env.PORT || 3000,
  nodeEnv: process.env.NODE_ENV || 'development',
  db: {
    user: process.env.DB_USER,
    password: process.env.DB_PASSWORD,
    connectString: process.env.DB_CONNECT_STRING,
    walletDir: process.env.DB_WALLET_DIR,
    walletPassword: process.env.DB_WALLET_PASSWORD,
  },
  jwt: {
    secret: process.env.JWT_SECRET,
    expiresIn: process.env.JWT_EXPIRES_IN || '8h',
  },
};