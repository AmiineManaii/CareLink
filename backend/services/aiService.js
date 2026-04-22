const axios = require("axios");
const socketService = require("./socketService");

class AIService {
  async analyzeImage(image, elderId) {
    if (!image) {
      throw { status: 400, message: "L'image est requise (base64)." };
    }
    if(!await axios.get("http://localhost:11434/api/tags")){
      throw { status: 500, message: "Ollama n'est pas disponible." };
    }



    // Traitement en arrière-plan
    this.processImageInBackground(image, elderId);
    

    return { status: "processing", message: "L'analyse a commencé." };
  }

  async processImageInBackground(image, elderId) {
    try {
      const ollamaUrl = process.env.OLLAMA_URL || "http://localhost:11434/api/chat";
      const response = await axios.post(ollamaUrl, {
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
      const io = socketService.getIO();
      if (io && elderId) {
        io.to(`elder:${elderId}`).emit("objectDetectionResult", {
          result: aiResponse,
          image: image
        });
      }
    } catch (error) {
      console.error("Erreur lors de l'appel à Ollama (background):", error.message);
      const io = socketService.getIO();
      if (io && elderId) {
        io.to(`elder:${elderId}`).emit("objectDetectionError", {
          error: "Erreur lors de l'analyse de l'image par l'IA locale.",
          details: error.message,
        });
      }
    }
  }
}

module.exports = new AIService();
