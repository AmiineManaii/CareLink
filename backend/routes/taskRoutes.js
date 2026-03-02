const express = require("express");
const router = express.Router();
const Task = require("../models/task");

// Create a new task
router.post("/add", async (req, res) => {
  try {
    const { elderId, title, description, time, date, reminderEnabled } = req.body;
    const task = new Task({ elderId, title, description, time, date, reminderEnabled });
    await task.save();
    res.status(201).json({ success: true, task });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "server_error" });
  }
});

// Get tasks for an elder on a specific date
router.get("/elder/:id", async (req, res) => {
  try {
    const { date } = req.query;
    let query = { elderId: req.params.id };

    if (date) {
      const startOfDay = new Date(date);
      startOfDay.setHours(0, 0, 0, 0);
      const endOfDay = new Date(date);
      endOfDay.setHours(23, 59, 59, 999);
      query.date = { $gte: startOfDay, $lte: endOfDay };
    }

    const tasks = await Task.find(query).sort({ time: 1 });
    res.json({ success: true, tasks });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "server_error" });
  }
});

// Update a task
router.put("/:id", async (req, res) => {
  try {
    const task = await Task.findByIdAndUpdate(req.params.id, req.body, { new: true });
    if (!task) return res.status(404).json({ error: "task_not_found" });
    res.json({ success: true, task });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "server_error" });
  }
});

// Delete a task
router.delete("/:id", async (req, res) => {
  try {
    const task = await Task.findByIdAndDelete(req.params.id);
    if (!task) return res.status(404).json({ error: "task_not_found" });
    res.json({ success: true, message: "task_deleted" });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "server_error" });
  }
});

module.exports = router;
