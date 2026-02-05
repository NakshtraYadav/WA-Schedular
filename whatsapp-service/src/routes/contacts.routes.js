/**
 * Contacts routes
 */
const express = require('express');
const router = express.Router();
const { getContacts, verifyNumber, verifyNumbers } = require('../services/whatsapp/contacts');

// GET /contacts
router.get('/contacts', async (req, res) => {
  const result = await getContacts();
  res.json(result);
});

// GET /verify/:phone - Check if single number is on WhatsApp
router.get('/verify/:phone', async (req, res) => {
  const result = await verifyNumber(req.params.phone);
  res.json(result);
});

// POST /verify - Check multiple numbers
router.post('/verify', async (req, res) => {
  const { phones } = req.body;
  if (!phones || !Array.isArray(phones)) {
    return res.status(400).json({ success: false, error: 'phones array required' });
  }
  const result = await verifyNumbers(phones);
  res.json(result);
});

module.exports = router;
