const express = require('express');
const router = express.Router();
const multer = require('multer');
const path = require('path');
const Medication = require('../models/medication');
const MedicationLog = require('../models/medicationLog');
const Caregiver = require('../models/caregiver');

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
const upload = multer({ storage });

// ── Routes spécifiques EN PREMIER (avant /:elderId) ──────────────────────────

// Confirmer la prise d'un médicament
router.post('/confirm-take', upload.single('audio'), async (req, res) => {
  try {
    const { medicationId, elderId, note, status } = req.body;
    if (!medicationId || !elderId) {
      return res.status(400).json({ error: 'medicationId et elderId requis' });
    }
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

// Historique par caregiver
router.get('/history/:caregiverId', async (req, res) => {
  try {
    const history = await MedicationLog.find({ caregiverId: req.params.caregiverId })
      .populate('medicationId', 'name dosage')
      .sort({ takenAt: -1 });
    res.json(history);
  } catch (error) {
    console.error('Erreur historique médicaments:', error);
    res.status(500).json({ error: 'Erreur serveur interne' });
  }
});

// Historique du jour pour un elder
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
    console.error("Erreur historique aujourd'hui senior:", error);
    res.status(500).json({ error: 'Erreur serveur interne' });
  }
});

// ── CRUD médicaments ──────────────────────────────────────────────────────────

// Ajouter un médicament
router.post('/', upload.single('photo'), async (req, res) => {
  try {
    const { name, dosage, frequency, times, days, startDate, endDate, instructions, caregiverId, elderId } = req.body;
    if (!name || !dosage || !frequency || !startDate || !elderId) {
      return res.status(400).json({ error: 'Missing required fields' });
    }
    let parsedTimes = [];
    try { parsedTimes = typeof times === 'string' ? JSON.parse(times) : (times || []); } catch { parsedTimes = []; }
    let parsedDays = [];
    try { parsedDays = typeof days === 'string' ? JSON.parse(days) : (days || []); } catch { parsedDays = []; }

    const photoUrl = req.file ? `/uploads/${req.file.filename}` : null;
    const medication = new Medication({
      name, dosage, frequency,
      times: parsedTimes,
      days: parsedDays,
      startDate,
      endDate: endDate ? new Date(endDate) : null,
      instructions, photoUrl, caregiverId, elderId
    });
    await medication.save();
    res.status(201).json(medication);
  } catch (error) {
    console.error('Error adding medication:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Récupérer les médicaments d'un elder — en DERNIER pour ne pas avaler /history/...
router.get('/:elderId', async (req, res) => {
  try {
    const medications = await Medication.find({ elderId: req.params.elderId });
    res.json(medications);
  } catch (error) {
    console.error('Error fetching medications:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Mettre à jour un médicament
router.put('/:id', upload.single('photo'), async (req, res) => {
  try {
    let updateData = { ...req.body };
    if (updateData.times && typeof updateData.times === 'string') {
      try { updateData.times = JSON.parse(updateData.times); } catch { updateData.times = []; }
    }
    if (updateData.days && typeof updateData.days === 'string') {
      try { updateData.days = JSON.parse(updateData.days); } catch { updateData.days = []; }
    }
    if (req.file) updateData.photoUrl = `/uploads/${req.file.filename}`;

    const medication = await Medication.findByIdAndUpdate(req.params.id, updateData, { new: true });
    if (!medication) return res.status(404).json({ error: 'Medication not found' });
    res.json(medication);
  } catch (error) {
    console.error('Error updating medication:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Supprimer un médicament
router.delete('/:id', async (req, res) => {
  try {
    await Medication.findByIdAndDelete(req.params.id);
    res.json({ message: 'Medication deleted' });
  } catch (error) {
    console.error('Error deleting medication:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

module.exports = router;