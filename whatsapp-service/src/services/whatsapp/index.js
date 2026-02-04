/**
 * WhatsApp services module exports
 */
module.exports = {
  ...require('./client'),
  ...require('./messaging'),
  ...require('./contacts')
};
