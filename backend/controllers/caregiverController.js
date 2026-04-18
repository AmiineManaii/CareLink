const caregiverService = require("../services/caregiverService");
const mongoose = require("mongoose");

class CaregiverController {
  async signup(req, res) {
    try {
      const { email, password } = req.body;
      if (!email || !password) {
        return res.status(400).json({ error: "email et password requis" });
      }
      const result = await caregiverService.signup(req.body);
      res.json(result);
    } catch (e) {
      res.status(e.status || 500).json({ error: e.message || "server_error" });
    }
  }

  async signin(req, res) {
    try {
      const { email, password } = req.body;
      const result = await caregiverService.signin(email, password);
      res.json(result);
    } catch (e) {
      res.status(e.status || 500).json({ error: e.message || "server_error" });
    }
  }

  async heartbeat(req, res) {
    try {
      const result = await caregiverService.heartbeat(req.params.id);
      res.json(result);
    } catch (e) {
      res.status(e.status || 500).json({ error: e.message || "server_error" });
    }
  }

  async getById(req, res) {
    try {
      if (!mongoose.Types.ObjectId.isValid(req.params.id)) {
        return res.status(400).json({ error: "Invalid caregiver ID format" });
      }
      const cg = await caregiverService.getById(req.params.id);
      res.json(cg);
    } catch (e) {
      res.status(e.status || 500).json({ error: e.message || "server_error" });
    }
  }

  async update(req, res) {
    try {
      if (!mongoose.Types.ObjectId.isValid(req.params.id)) {
        return res.status(400).json({ error: "Invalid caregiver ID format" });
      }
      const cg = await caregiverService.update(req.params.id, req.body);
      res.json(cg);
    } catch (e) {
      res.status(e.status || 500).json({ error: e.message || "server_error" });
    }
  }
}

module.exports = new CaregiverController();
