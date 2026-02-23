const mongoose = require('mongoose');

const medicationSchema = new mongoose.Schema({
  name: { type: String, required: true },
  dosage: { type: String, required: true },
  frequency: { type: String, required: true },
  days: [{ type: Number }], // 1=Monday, 7=Sunday
  times: [{ type: String }], // Array of strings "HH:mm"
  startDate: { type: Date, required: true },
  endDate: { type: Date },
  instructions: { type: String },
  photoUrl: { type: String }, // Can be base64 or URL
  active: { type: Boolean, default: true },
  caregiverId: { type: mongoose.Schema.Types.ObjectId, ref: 'Caregiver' },
  elderId: { type: mongoose.Schema.Types.ObjectId, ref: 'Elder', required: true },
}, { timestamps: true });

module.exports = mongoose.model('Medication', medicationSchema);
