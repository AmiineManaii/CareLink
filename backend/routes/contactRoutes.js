const express = require('express');
const router = express.Router();
const multer = require('multer');
const Contact = require('../models/contact');
const uploadToCloudinary = require('../config/uploadToCloudinary');

// ✅ memoryStorage — pas de fichiers locaux
const upload = multer({ storage: multer.memoryStorage() });

// Create contact
router.post('/', upload.single('photo'), async (req, res) => {
  try {
    const { name, phone, relation, elderId, caregiverId } = req.body;

    // ✅ Upload vers Cloudinary si une photo est fournie
    let photoUrl = null;
    if (req.file) {
      photoUrl = await uploadToCloudinary(req.file.buffer, 'contacts');
    }

    const contact = new Contact({
      name,
      phone,
      relation,
      elderId,
      caregiverId,
      photoUrl,
    });

    await contact.save();
    res.status(201).json(contact);
  } catch (error) {
    console.error('Error creating contact:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Get contacts for elder
router.get('/elder/:elderId', async (req, res) => {
  try {
    const contacts = await Contact.find({ elderId: req.params.elderId });
    res.json(contacts);
  } catch (error) {
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Delete contact
router.delete('/:id', async (req, res) => {
  try {
    await Contact.findByIdAndDelete(req.params.id);
    res.json({ message: 'Contact deleted' });
  } catch (error) {
    res.status(500).json({ error: 'Internal server error' });
  }
});

module.exports = router;