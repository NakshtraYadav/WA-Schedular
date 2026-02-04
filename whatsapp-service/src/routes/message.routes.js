/**
 * Message routes
 */
const express = require('express');
const router = express.Router();
const { sendMessage } = require('../services/whatsapp/messaging');

// POST /send
router.post('/send', async (req, res) => {
  const { phone, message } = req.body;

  if (!phone || !message) {
    return res.status(400).json({
      success: false,
      error: 'Phone and message are required'
    });
  }

  const result = await sendMessage(phone, message);
  res.json(result);
});

module.exports = router;
