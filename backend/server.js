const express = require("express");
const mongoose = require("mongoose");
const cors = require("cors");
require("dotenv").config();
const userRoutes = require("./routes/userRoutes");
const elderRoutes = require("./routes/elderRoutes");
const caregiverRoutes = require("./routes/caregiverRoutes");



const app = express();
app.use(cors());
app.use(express.json());
app.use("/users", userRoutes);
app.use("/elder", elderRoutes);
app.use("/caregiver", caregiverRoutes);

const mongoUri = process.env.MONGODB_URI || "mongodb://127.0.0.1:27017/flutterDB";
mongoose
  .connect(mongoUri)
  .then(() => console.log("✅ MongoDB connecté"))
  .catch((err) => console.log(err));

const port = process.env.PORT || 5000;
app.listen(port, "0.0.0.0", () => {
  console.log(`🚀 Serveur lancé sur http://localhost:${port}`);
});
