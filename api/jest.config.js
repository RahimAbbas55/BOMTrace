module.exports = {
  testEnvironment: 'node',
  testMatch: ['**/tests/**/*.test.js'],
  // the first database connection can take a few seconds
  testTimeout: 30000,
  verbose: true,
};