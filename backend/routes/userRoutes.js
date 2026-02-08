const express = require("express");
const router = express.Router();
const User = require("../models/user");

router.post("/add", async (req, res) => {
  const user = new User(req.body);
  await user.save();
  res.send("✅ User ajouté !");
});

router.get("/", async (req, res) => {
  const users = await User.find();
  res.json(users);
});

module.exports = router;
