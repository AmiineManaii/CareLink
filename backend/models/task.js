const mongoose = require("mongoose");

const TaskSchema = new mongoose.Schema(
  {
    elderId: { type: mongoose.Schema.Types.ObjectId, ref: "Elder", required: true },
    title: { type: String, required: true },
    description: { type: String },
    time: { type: String, required: true }, // Format HH:mm
    date: { type: Date, required: true },
    isCompleted: { type: Boolean, default: false },
    reminderEnabled: { type: Boolean, default: true },
  },
  { timestamps: true }
);

module.exports = mongoose.model("Task", TaskSchema);
