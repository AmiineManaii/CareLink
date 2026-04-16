const express = require("express");
const router = express.Router();
const bcrypt = require("bcryptjs");
const mongoose = require("mongoose");
const Caregiver = require("../models/caregiver");
const Elder = require("../models/elder");

router.post("/signup", async (req, res) => {
  try {
    const { email, password, phone, gender, elderCode, firstName, lastName } = req.body;
    if (!email || !password) {
      return res.status(400).json({ error: "email et password requis" });
    }
    const existing = await Caregiver.findOne({ email });
    if (existing) {
      return res.status(409).json({ error: "email déjà utilisé" });
    }
    const hash = await bcrypt.hash(password, 10);
    let linkedElderId = null;
    if (elderCode) {
      const elder = await Elder.findOne({ relationCode: elderCode });
      if (elder) linkedElderId = elder._id;
    }
    const caregiver = await Caregiver.create({
      email,
      passwordHash: hash,
      phone,
      gender,
      firstName,
      lastName,
      linkedElderId,
    });
    res.json({ caregiverId: caregiver._id, linkedElderId });
  } catch (e) {
    console.error(e);
    res.status(500).json({ error: "server_error" });
  }
});

router.post("/signin", async (req, res) => {
  try {
    const { email, password } = req.body;
    const cg = await Caregiver.findOne({ email });
    if (!cg) return res.status(401).json({ error: "invalid_credentials" });
    const ok = await bcrypt.compare(password, cg.passwordHash);
    if (!ok) return res.status(401).json({ error: "invalid_credentials" });
    cg.lastActiveAt = new Date();
    await cg.save();
    res.json({ caregiverId: cg._id, linkedElderId: cg.linkedElderId || null });
  } catch (e) {
    console.error(e);
    res.status(500).json({ error: "server_error" });
  }
});

router.post("/:id/heartbeat", async (req, res) => {
  try {
    const cg = await Caregiver.findByIdAndUpdate(
      req.params.id,
      { lastActiveAt: new Date() },
      { new: true }
    );
    if (!cg) return res.status(404).json({ error: "Caregiver not found" });
    let elder = null;
    let elderOnline = false;
    let elderLastActiveAt = null;
    if (cg.linkedElderId) {
      elder = await Elder.findById(cg.linkedElderId);
      if (elder && elder.lastActiveAt) {
        elderLastActiveAt = elder.lastActiveAt;
        const diff = Date.now() - new Date(elder.lastActiveAt).getTime();
        elderOnline = diff < 60000;
      }
    }
    let online = false;
    let lastActiveAt = cg.lastActiveAt;
    if (lastActiveAt) {
      const diff = Date.now() - new Date(lastActiveAt).getTime();
      online = diff < 60000;
    }
    res.json({
      caregiverId: cg._id,
      online,
      lastActiveAt,
      elder: elder
        ? {
            elderId: elder._id,
            online: elderOnline,
            lastActiveAt: elderLastActiveAt,
          }
        : null,
    });
  } catch (e) {
    console.error(e);
    res.status(500).json({ error: "server_error" });
  }
});

router.get("/:id", async (req, res) => {
  try {
    if (!mongoose.Types.ObjectId.isValid(req.params.id)) {
      return res.status(400).json({ error: "Invalid caregiver ID format" });
    }
    const cg = await Caregiver.findById(req.params.id).select("-passwordHash");
    if (!cg) return res.status(404).json({ error: "Caregiver not found" });
    res.json(cg);
  } catch (e) {
    console.error("Error in GET /caregiver/:id:", e);
    res.status(500).json({ error: "server_error" });
  }
});

router.put("/:id", async (req, res) => {
  try {
    if (!mongoose.Types.ObjectId.isValid(req.params.id)) {
      return res.status(400).json({ error: "Invalid caregiver ID format" });
    }
    const { firstName, lastName, phone, gender, email } = req.body;
    const cg = await Caregiver.findByIdAndUpdate(
      req.params.id,
      { firstName, lastName, phone, gender, email },
      { new: true }
    ).select("-passwordHash");
    if (!cg) return res.status(404).json({ error: "Caregiver not found" });
    res.json(cg);
  } catch (e) {
    console.error("Error in PUT /caregiver/:id:", e);
    res.status(500).json({ error: "server_error" });
  }
});

module.exports = router;
