const express = require("express");
const router = express.Router();
const elderController = require("../controllers/elderController");

router.post("/signup-face", elderController.signupFace);
router.post("/signin-face", elderController.signinFace);
router.post("/update-profile", elderController.updateProfile);
router.get("/verify-code/:code", elderController.verifyCode);
router.get("/:id", elderController.getById);
router.post("/:id/heartbeat", elderController.heartbeat);

module.exports = router;
