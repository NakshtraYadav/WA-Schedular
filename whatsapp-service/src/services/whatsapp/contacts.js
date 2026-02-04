/**
 * WhatsApp contacts functionality
 */
const { getClient, getState } = require('./client');
const { log } = require('../../utils/logger');

const getContacts = async () => {
  const { isReady } = getState();
  const client = getClient();

  if (!isReady || !client) {
    return {
      success: false,
      error: 'WhatsApp not connected',
      contacts: []
    };
  }

  try {
    log('INFO', 'Fetching WhatsApp contacts...');
    const contacts = await client.getContacts();

    const formattedContacts = contacts
      .filter(c => c.id.server === 'c.us' && !c.isMe && !c.isGroup)
      .map(c => ({
        id: c.id._serialized,
        number: c.id.user,
        name: c.name || c.pushname || c.id.user,
        pushname: c.pushname,
        isMyContact: c.isMyContact
      }))
      .slice(0, 500);

    log('INFO', `Found ${formattedContacts.length} contacts`);

    return {
      success: true,
      contacts: formattedContacts
    };
  } catch (error) {
    log('ERROR', 'Get contacts error:', error.message);
    return {
      success: false,
      error: error.message,
      contacts: []
    };
  }
};

module.exports = {
  getContacts
};
