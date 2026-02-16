const mongoose = require("mongoose");

const CaregiverSchema = new mongoose.Schema(
  {
    email: { type: String, required: true, unique: true, index: true },
    passwordHash: { type: String, required: true },
    firstName: { type: String },
    lastName: { type: String },
    phone: { type: String },
    gender: { type: String },
    lastActiveAt: { type: Date },
    linkedElderId: { type: mongoose.Schema.Types.ObjectId, ref: "Elder" },
  },
  { timestamps: true }
);

module.exports = mongoose.model("Caregiver", CaregiverSchema);
