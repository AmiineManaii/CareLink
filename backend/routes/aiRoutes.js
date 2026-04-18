const express = require("express");
const router = express.Router();
const axios = require("axios");

router.post("/analyze-image", async (req, res) => {
  const { image, elderId } = req.body;

  if (!image) {
    return res.status(400).json({ error: "L'image est requise (base64)." });
  }

  // Répondre immédiatement
  res.json({ status: "processing", message: "L'analyse a commencé." });

  // Traitement en arrière-plan
  (async () => {
    try {
      const response = await axios.post("http://localhost:11434/api/chat", {
        model: "qwen3-vl:2b-instruct-q4_K_M",
        messages: [
          {
            role: "user",
            content: `
              Identify the main visible object in this image.

              Rules:
              - Be as specific as possible (include type, state, or context)
              - Prefer compound nouns (e.g., "fruit juice", "water bottle", "coffee cup")
              - Use 1 to 3 words maximum
              - No sentence
              - No explanation
              - No punctuation
              - Avoid overly generic words like "object", "thing", "fruit"

              Answer:
            `,
            images: [image],
          },
        ],
        stream: false,
      });

      const aiResponse = response.data.message.content.trim();
      
      // Envoyer le résultat via socket.io
      const io = req.app.get("io");
      if (io && elderId) {
        io.to(`elder:${elderId}`).emit("objectDetectionResult", {
          result: aiResponse,
          image: image // Optionnel: renvoyer l'image si besoin
        });
      }
    } catch (error) {
      console.error("Erreur lors de l'appel à Ollama (background):", error.message);
      const io = req.app.get("io");
      if (io && elderId) {
        io.to(`elder:${elderId}`).emit("objectDetectionError", {
          error: "Erreur lors de l'analyse de l'image par l'IA locale.",
          details: error.message,
        });
      }
    }
  })();
});

module.exports = router;
