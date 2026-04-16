const express = require('express');
const router = express.Router();
const Contact = require('../models/contact');
const multer = require('multer');
const path = require('path');

const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    cb(null, path.join(__dirname, '..', 'uploads'));
  },
  filename: (req, file, cb) => {
    cb(null, Date.now() + '-' + file.fieldname + path.extname(file.originalname));
  }
});

const upload = multer({ storage: storage });

// Create contact
router.post('/', upload.single('photo'), async (req, res) => {
  try {
    const { name, phone, relation, elderId, caregiverId } = req.body;
    const photoUrl = req.file ? `/uploads/${req.file.filename}` : null;

    const contact = new Contact({
      name,
      phone,
      relation,
      elderId,
      caregiverId,
      photoUrl
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
