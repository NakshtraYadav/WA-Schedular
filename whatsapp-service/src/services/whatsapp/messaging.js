/**
 * WhatsApp messaging functionality
 */
const { getClient, getState } = require('./client');
const { log } = require('../../utils/logger');
const { formatPhoneNumber } = require('../../utils/phone');

const sendMessage = async (phone, message) => {
  const { isReady } = getState();
  const client = getClient();

  if (!isReady || !client) {
    return {
      success: false,
      error: 'WhatsApp not connected'
    };
  }

  try {
    const formattedPhone = formatPhoneNumber(phone);
    const chatId = formattedPhone + '@c.us';

    log('INFO', `Sending message to ${chatId}`);

    const result = await client.sendMessage(chatId, message);

    return {
      success: true,
      messageId: result.id._serialized,
      timestamp: new Date().toISOString()
    };
  } catch (error) {
    log('ERROR', 'Send message error:', error.message);
    return {
      success: false,
      error: error.message
    };
  }
};

module.exports = {
  sendMessage
};
