const mongoose = require("mongoose");

const AlertSchema = new mongoose.Schema(
  {
    elderId: { type: mongoose.Schema.Types.ObjectId, ref: "Elder", required: true },
    caregiverId: { type: mongoose.Schema.Types.ObjectId, ref: "Caregiver", required: true },
    type: { type: String, default: "sos" },
    message: { type: String },
    latitude: { type: String },
    longitude: { type: String },
    read: { type: Boolean, default: false },
    imageUrl: {type:String},
  },
  { timestamps: true }
);

module.exports = mongoose.model("Alert", AlertSchema);

