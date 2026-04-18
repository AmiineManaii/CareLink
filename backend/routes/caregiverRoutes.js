const express = require("express");
const router = express.Router();
const caregiverController = require("../controllers/caregiverController");

router.post("/signup", caregiverController.signup);
router.post("/signin", caregiverController.signin);
router.post("/:id/heartbeat", caregiverController.heartbeat);
router.get("/:id", caregiverController.getById);
router.put("/:id", caregiverController.update);

module.exports = router;
