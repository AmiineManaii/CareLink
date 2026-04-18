const express = require("express");
const router = express.Router();
const aiController = require("../controllers/aiController");

router.post("/analyze-image", aiController.analyzeImage);

module.exports = router;
