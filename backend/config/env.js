/**
 * PulseTrack — Environment Variable Validation
 * Fail fast if required secrets are missing at startup.
 */

const REQUIRED_VARS = [
  'MONGO_URI',
  'JWT_SECRET',
  'JWT_REFRESH_SECRET',
  'EMAIL_USER',
  'EMAIL_PASS',
];

function validateEnv() {
  const missing = REQUIRED_VARS.filter(key => !process.env[key]);
  if (missing.length > 0) {
    console.error(`❌ Missing required environment variables: ${missing.join(', ')}`);
    console.error('   Create a .env file based on .env.example');
    process.exit(1);
  }
}

module.exports = { validateEnv };
