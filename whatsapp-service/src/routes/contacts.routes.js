/**
 * Contacts routes
 */
const express = require('express');
const router = express.Router();
const { getContacts } = require('../services/whatsapp/contacts');

// GET /contacts
router.get('/contacts', async (req, res) => {
  const result = await getContacts();
  res.json(result);
});

module.exports = router;
