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

/**
 * Check if a phone number is registered on WhatsApp
 */
const verifyNumber = async (phoneNumber) => {
  const { isReady } = getState();
  const client = getClient();

  if (!isReady || !client) {
    return {
      success: false,
      error: 'WhatsApp not connected',
      isRegistered: false
    };
  }

  try {
    // Clean the phone number (remove spaces, dashes, plus sign)
    const cleanNumber = phoneNumber.replace(/[\s\-\+]/g, '');
    
    // Format for WhatsApp (number@c.us)
    const numberId = await client.getNumberId(cleanNumber);
    
    if (numberId) {
      log('INFO', `Number ${cleanNumber} is registered on WhatsApp`);
      return {
        success: true,
        isRegistered: true,
        whatsappId: numberId._serialized,
        formattedNumber: numberId.user
      };
    } else {
      log('INFO', `Number ${cleanNumber} is NOT on WhatsApp`);
      return {
        success: true,
        isRegistered: false,
        formattedNumber: cleanNumber
      };
    }
  } catch (error) {
    log('ERROR', 'Verify number error:', error.message);
    return {
      success: false,
      error: error.message,
      isRegistered: false
    };
  }
};

/**
 * Verify multiple phone numbers at once (optimized with parallel batches)
 */
const verifyNumbers = async (phoneNumbers) => {
  const { isReady } = getState();
  const client = getClient();

  if (!isReady || !client) {
    return {
      success: false,
      error: 'WhatsApp not connected',
      results: []
    };
  }

  try {
    const results = [];
    const BATCH_SIZE = 5; // Process 5 numbers in parallel
    
    // Helper to verify a single number
    const verifySingleNumber = async (phone) => {
      const cleanNumber = phone.replace(/[\s\-\+]/g, '');
      try {
        const numberId = await client.getNumberId(cleanNumber);
        return {
          phone: phone,
          cleanNumber: cleanNumber,
          isRegistered: !!numberId,
          whatsappId: numberId ? numberId._serialized : null
        };
      } catch (e) {
        return {
          phone: phone,
          cleanNumber: cleanNumber,
          isRegistered: false,
          error: e.message
        };
      }
    };

    // Process in batches of BATCH_SIZE
    for (let i = 0; i < phoneNumbers.length; i += BATCH_SIZE) {
      const batch = phoneNumbers.slice(i, i + BATCH_SIZE);
      const batchResults = await Promise.all(batch.map(verifySingleNumber));
      results.push(...batchResults);
      
      // Small delay between batches to avoid rate limiting
      if (i + BATCH_SIZE < phoneNumbers.length) {
        await new Promise(resolve => setTimeout(resolve, 500));
      }
    }

    const registered = results.filter(r => r.isRegistered).length;
    log('INFO', `Verified ${phoneNumbers.length} numbers: ${registered} on WhatsApp`);

    return {
      success: true,
      total: phoneNumbers.length,
      registered: registered,
      notRegistered: phoneNumbers.length - registered,
      results: results
    };
  } catch (error) {
    log('ERROR', 'Verify numbers error:', error.message);
    return {
      success: false,
      error: error.message,
      results: []
    };
  }
};

module.exports = {
  getContacts,
  verifyNumber,
  verifyNumbers
};
