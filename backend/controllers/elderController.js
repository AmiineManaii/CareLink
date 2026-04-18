const elderService = require("../services/elderService");

class ElderController {
  async signupFace(req, res) {
    try {
      const { embedding, profile } = req.body;
      if (!embedding || !Array.isArray(embedding)) {
        return res.status(400).json({ error: "embedding requis" });
      }
      const result = await elderService.signupFace(embedding, profile);
      res.json(result);
    } catch (e) {
      res.status(e.status || 500).json({ error: e.message || "server_error" });
    }
  }

  async signinFace(req, res) {
    try {
      const { embedding } = req.body;
      if (!embedding || !Array.isArray(embedding)) {
        return res.status(400).json({ error: "embedding requis" });
      }
      const result = await elderService.signinFace(embedding);
      res.json(result);
    } catch (e) {
      res.status(e.status || 500).json({ error: e.message || "server_error" });
    }
  }

  async updateProfile(req, res) {
    try {
      const { elderId, profile } = req.body;
      if (!elderId || !profile) {
        return res.status(400).json({ error: "elderId et profile requis" });
      }
      const result = await elderService.updateProfile(elderId, profile);
      res.json(result);
    } catch (e) {
      res.status(e.status || 500).json({ error: e.message || "server_error" });
    }
  }

  async updateProfileWithImage(req, res) {
    try {
      const { elderId, profile: profileRaw } = req.body;
      if (!elderId || !profileRaw) {
        return res.status(400).json({ error: "elderId et profile requis" });
      }
      let profile;
      try {
        profile = typeof profileRaw === "string" ? JSON.parse(profileRaw) : profileRaw;
      } catch {
        return res.status(400).json({ error: "profile JSON invalide" });
      }
      if (req.file) {
        profile.photoUrl = `/uploads/${req.file.filename}`;
      }
      const result = await elderService.updateProfile(elderId, profile);
      res.json(result);
    } catch (e) {
      res.status(e.status || 500).json({ error: e.message || "server_error" });
    }
  }

  async verifyCode(req, res) {
    try {
      const result = await elderService.verifyCode(req.params.code);
      res.json(result);
    } catch (e) {
      res.status(e.status || 500).json({ error: e.message || "server_error" });
    }
  }

  async getById(req, res) {
    try {
      const result = await elderService.getById(req.params.id);
      res.json(result);
    } catch (e) {
      res.status(e.status || 500).json({ error: e.message || "server_error" });
    }
  }

  async heartbeat(req, res) {
    try {
      const result = await elderService.heartbeat(req.params.id);
      res.json(result);
    } catch (e) {
      res.status(e.status || 500).json({ error: e.message || "server_error" });
    }
  }

  async getCaregiver(req, res) {
    try {
      const result = await elderService.getCaregiver(req.params.id);
      res.json(result);
    } catch (e) {
      res.status(e.status || 500).json({ error: e.message || "server_error" });
    }
  }
}

module.exports = new ElderController();