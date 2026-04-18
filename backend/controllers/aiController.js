const aiService = require("../services/aiService");

class AIController {
  async analyzeImage(req, res) {
    try {
      const { image, elderId } = req.body;
      const result = await aiService.analyzeImage(image, elderId);
      res.json(result);
    } catch (e) {
      res.status(e.status || 500).json({ error: e.message || "server_error" });
    }
  }
}

module.exports = new AIController();
