const express = require('express');
const router = express.Router();
const multer = require('multer');
const path = require('path');
const Medication = require('../models/medication');

// Configure Multer for file uploads
const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    cb(null, 'uploads/');
  },
  filename: (req, file, cb) => {
    cb(null, Date.now() + path.extname(file.originalname));
  }
});

const upload = multer({ storage: storage });

// Add medication with optional photo
router.post('/', upload.single('photo'), async (req, res) => {
  try {
    const { name, dosage, frequency, times, days, startDate, endDate, instructions, caregiverId, elderId } = req.body;
    
    // Validate required fields
    if (!name || !dosage || !frequency || !startDate || !elderId) {
      return res.status(400).json({ error: 'Missing required fields' });
    }

    let parsedTimes = [];
    try {
      // If times is a string (from FormData), parse it
      parsedTimes = typeof times === 'string' ? JSON.parse(times) : times;
    } catch (e) {
      parsedTimes = [];
    }

    let parsedDays = [];
    try {
      // If days is a string (from FormData), parse it
      parsedDays = typeof days === 'string' ? JSON.parse(days) : days;
    } catch (e) {
      console.error("Error parsing days:", e);
      parsedDays = [];
    }

    const photoUrl = req.file ? `/uploads/${req.file.filename}` : null;

    const medication = new Medication({
      name,
      dosage,
      frequency,
      times: parsedTimes,
      days: parsedDays,
      startDate,
      endDate: endDate ? new Date(endDate) : null,
      instructions,
      photoUrl,
      caregiverId,
      elderId
    });

    await medication.save();
    res.status(201).json(medication);
  } catch (error) {
    console.error('Error adding medication:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Get medications for an elder
router.get('/:elderId', async (req, res) => {
  try {
    const { elderId } = req.params;
    const medications = await Medication.find({ elderId });
    res.json(medications);
  } catch (error) {
    console.error('Error fetching medications:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Update medication
router.put('/:id', upload.single('photo'), async (req, res) => {
  try {
    const { id } = req.params;
    let updateData = { ...req.body };

    // Handle times array parsing
    if (updateData.times && typeof updateData.times === 'string') {
      try {
        updateData.times = JSON.parse(updateData.times);
      } catch (e) {
        updateData.times = [];
      }
    }

    // Handle days array parsing
    if (updateData.days && typeof updateData.days === 'string') {
      try {
        updateData.days = JSON.parse(updateData.days);
      } catch (e) {
        console.error("Error parsing days update:", e);
        updateData.days = [];
      }
    }

    // Handle photo
    if (req.file) {
      updateData.photoUrl = `/uploads/${req.file.filename}`;
    }

    const medication = await Medication.findByIdAndUpdate(id, updateData, { new: true });
    if (!medication) {
      return res.status(404).json({ error: 'Medication not found' });
    }
    res.json(medication);
  } catch (error) {
    console.error('Error updating medication:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Delete medication
router.delete('/:id', async (req, res) => {
  try {
    const { id } = req.params;
    await Medication.findByIdAndDelete(id);
    res.json({ message: 'Medication deleted' });
  } catch (error) {
    console.error('Error deleting medication:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

module.exports = router;
