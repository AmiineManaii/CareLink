const express = require("express");
const router = express.Router();
const Alert = require("../models/alert");
const Caregiver = require("../models/caregiver");
const Elder = require("../models/elder");

router.post("/sos", async (req, res) => {
  try {
    const { elderId, latitude, longitude } = req.body;
    if (!elderId) {
      return res.status(400).json({ error: "elderId requis" });
    }
    const elder = await Elder.findById(elderId);
    if (!elder) {
      return res.status(404).json({ error: "elder introuvable" });
    }
    const caregiver = await Caregiver.findOne({ linkedElderId: elder._id });
    if (!caregiver) {
      return res.status(404).json({ error: "caregiver introuvable" });
    }

    const parts = [];
    if (elder.profile?.firstName || elder.profile?.lastName) {
      parts.push(
        `SOS pour ${elder.profile.firstName || ""} ${elder.profile.lastName || ""}`.trim()
      );
    } else {
      parts.push("SOS déclenché par le senior");
    }
    if (latitude && longitude) {
      parts.push(`Localisation: ${latitude}, ${longitude}`);
    }

    const alert = await Alert.create({
      elderId: elder._id,
      caregiverId: caregiver._id,
      type: "sos",
      message: parts.join(" – "),
      latitude,
      longitude,
    });

    res.json({ ok: true, alertId: alert._id });
  } catch (e) {
    console.error(e);
    res.status(500).json({ error: "server_error" });
  }
});

router.get("/elder/:id", async (req, res) => {
  try {
    const alerts = await Alert.find({ elderId: req.params.id })
      .sort({ createdAt: -1 })
      .lean();
    res.json(alerts);
  } catch (e) {
    console.error(e);
    res.status(500).json({ error: "server_error" });
  }
});

router.get("/caregiver/:id", async (req, res) => {
  try {
    const alerts = await Alert.find({ caregiverId: req.params.id })
      .sort({ createdAt: -1 })
      .lean();
    res.json(alerts);
  } catch (e) {
    console.error(e);
    res.status(500).json({ error: "server_error" });
  }
});

router.post("/:id/read", async (req, res) => {
  try {
    const alert = await Alert.findByIdAndUpdate(
      req.params.id,
      { read: true },
      { new: true }
    );
    if (!alert) return res.status(404).json({ error: "alert_not_found" });
    res.json({ ok: true });
  } catch (e) {
    console.error(e);
    res.status(500).json({ error: "server_error" });
  }
});

module.exports = router;

