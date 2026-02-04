/**
 * Logger utility
 */
const log = (level, ...args) => {
  const timestamp = new Date().toISOString();
  console.log(`[${timestamp}] [WA-SERVICE] [${level}]`, ...args);
};

module.exports = { log };
