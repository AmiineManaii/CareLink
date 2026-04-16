const express = require("express");
const router = express.Router();
const axios = require("axios");

router.post("/analyze-image", async (req, res) => {
  const { image } = req.body;

  if (!image) {
    return res.status(400).json({ error: "L'image est requise (base64)." });
  }

  try {
    const response = await axios.post("http://localhost:11434/api/chat", {
      model: "qwen3-vl:2b-instruct-q4_K_M",
      messages: [
        {
          role: "user",
          content: `
            You must follow these rules strictly:
            - Output only one single word
            - No sentences
            - No explanations
            - No punctuation

            What is the main object in this image?
          `,
          images: [image],
        },
      ],
      stream: false,
    });

    const aiResponse = response.data.message.content.trim();
    res.json({ result: aiResponse });
  } catch (error) {
    console.error("Erreur lors de l'appel à Ollama:", error.message);
    res.status(500).json({
      error: "Erreur lors de l'analyse de l'image par l'IA locale.",
      details: error.message,
    });
  }
});

module.exports = router;
