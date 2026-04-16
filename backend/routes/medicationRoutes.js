const express = require('express');
const router = express.Router();
const multer = require('multer');
const path = require('path');
const Medication = require('../models/medication');
const MedicationLog = require('../models/medicationLog');
const Caregiver = require('../models/caregiver');

// Configure Multer for file uploads (photos et audio)
const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    const uploadPath = path.join(__dirname, '..', 'uploads');
    cb(null, uploadPath);
  },
  filename: (req, file, cb) => {
    const ext = path.extname(file.originalname) || (file.fieldname === 'audio' ? '.m4a' : '.jpg');
    cb(null, Date.now() + '-' + file.fieldname + ext);
  }
});

const upload = multer({ storage: storage });

// Route pour confirmer la prise d'un médicament (avec audio/note optionnel)
router.post('/confirm-take', upload.single('audio'), async (req, res) => {
  try {
    const { medicationId, elderId, note, status } = req.body;
    
    if (!medicationId || !elderId) {
      return res.status(400).json({ error: 'medicationId et elderId requis' });
    }

    // Trouver le caregiver lié pour l'historique
    const caregiver = await Caregiver.findOne({ linkedElderId: elderId });
    if (!caregiver) {
      return res.status(404).json({ error: 'Caregiver non trouvé pour ce senior' });
    }

    const audioUrl = req.file ? `/uploads/${req.file.filename}` : null;

    const log = new MedicationLog({
      medicationId,
      elderId,
      caregiverId: caregiver._id,
      status: status || 'taken',
      note,
      audioUrl,
      takenAt: new Date()
    });

    await log.save();
    res.status(201).json(log);
  } catch (error) {
    console.error('Erreur confirmation médicament:', error);
    res.status(500).json({ error: 'Erreur serveur interne' });
  }
});

// Route pour récupérer l'historique des prises pour un aidant
router.get('/history/:caregiverId', async (req, res) => {
  try {
    const { caregiverId } = req.params;
    const history = await MedicationLog.find({ caregiverId })
      .populate('medicationId', 'name dosage')
      .sort({ takenAt: -1 });
    res.json(history);
  } catch (error) {
    console.error('Erreur historique médicaments:', error);
    res.status(500).json({ error: 'Erreur serveur interne' });
  }
});

// Route pour récupérer l'historique des prises d'aujourd'hui pour un senior
router.get('/history/elder/:elderId/today', async (req, res) => {
  try {
    const { elderId } = req.params;
    const startOfDay = new Date();
    startOfDay.setHours(0, 0, 0, 0);
    
    const endOfDay = new Date();
    endOfDay.setHours(23, 59, 59, 999);

    const history = await MedicationLog.find({
      elderId,
      takenAt: { $gte: startOfDay, $lte: endOfDay }
    }).populate('medicationId', 'name');

    res.json(history);
  } catch (error) {
    console.error('Erreur historique aujourd’hui senior:', error);
    res.status(500).json({ error: 'Erreur serveur interne' });
  }
});

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
