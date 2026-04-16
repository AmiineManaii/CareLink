const mongoose = require('mongoose');

const contactSchema = new mongoose.Schema({
  name: {
    type: String,
    required: true
  },
  phone: {
    type: String,
    required: true
  },
  relation: {
    type: String,
    required: true
  },
  elderId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Elder',
    required: true
  },
  caregiverId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Caregiver',
    required: true
  },
  photoUrl: {
    type: String
  },
  createdAt: {
    type: Date,
    default: Date.now
  }
});

module.exports = mongoose.model('Contact', contactSchema);
