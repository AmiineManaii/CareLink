const express = require("express");
const router = express.Router();
const bcrypt = require("bcryptjs");
const Caregiver = require("../models/caregiver");
const Elder = require("../models/elder");

router.post("/signup", async (req, res) => {
  try {
    const { email, password, phone, gender, elderCode } = req.body;
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
    res.json({ caregiverId: cg._id, linkedElderId: cg.linkedElderId || null });
  } catch (e) {
    console.error(e);
    res.status(500).json({ error: "server_error" });
  }
});

module.exports = router;
