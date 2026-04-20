const mongoose = require("mongoose");

const ElderSchema = new mongoose.Schema(
  {
    profile: {
      firstName: { type: String },
      lastName: { type: String },
      name: { type: String }, // compat
      phone: { type: String }, // compat
      gender: { type: String },
      age: { type: Number },
      email: { type: String },
      photoUrl: { type: String },
    },
    relationCode: { type: String, unique: true, index: true },
    embeddings: {
      type: [[Number]], // array of embedding vectors
      default: [],
    },
    lastActiveAt: { type: Date },
  },
  { timestamps: true }
);

module.exports = mongoose.model("Elder", ElderSchema);
