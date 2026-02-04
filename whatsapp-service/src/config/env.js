/**
 * Environment configuration
 */
const PORT = process.env.WA_PORT || 3001;
const SESSION_PATH = process.env.SESSION_PATH || './.wwebjs_auth';

module.exports = {
  PORT,
  SESSION_PATH
};
