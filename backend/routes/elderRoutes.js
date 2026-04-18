const express = require("express");
const router = express.Router();
const multer = require("multer");
const path = require("path");
const elderController = require("../controllers/elderController");

const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    cb(null, path.join(__dirname, "..", "uploads"));
  },
  filename: (req, file, cb) => {
    cb(null, Date.now() + "-" + file.fieldname + path.extname(file.originalname));
  },
});
const upload = multer({ storage });

router.post("/signup-face", elderController.signupFace);
router.post("/signin-face", elderController.signinFace);
router.post("/update-profile", elderController.updateProfile);
router.post("/update-profile-with-image", upload.single("photo"), elderController.updateProfileWithImage);
router.get("/verify-code/:code", elderController.verifyCode);
router.get("/:id/caregiver", elderController.getCaregiver);
router.get("/:id", elderController.getById);
router.post("/:id/heartbeat", elderController.heartbeat);

module.exports = router;