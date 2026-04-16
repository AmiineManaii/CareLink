const mongoose = require('mongoose');

const medicationLogSchema = new mongoose.Schema({
  medicationId: { type: mongoose.Schema.Types.ObjectId, ref: 'Medication', required: true },
  elderId: { type: mongoose.Schema.Types.ObjectId, ref: 'Elder', required: true },
  caregiverId: { type: mongoose.Schema.Types.ObjectId, ref: 'Caregiver', required: true },
  status: { type: String, enum: ['taken', 'skipped', 'missed'], default: 'taken' },
  takenAt: { type: Date, default: Date.now },
  note: { type: String }, // Texte saisi ou transcrit
  audioUrl: { type: String }, // Chemin vers le fichier audio enregistré
}, { timestamps: true });

module.exports = mongoose.model('MedicationLog', medicationLogSchema);
