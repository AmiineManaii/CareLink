const mongoose = require("mongoose");
require("dotenv").config();

const connectDB = async () => {
  const mongoUri = process.env.MONGODB_URI || "mongodb://127.0.0.1:27017/flutterDB";
  try {
    await mongoose.connect(mongoUri);
    console.log("✅ MongoDB connecté");
  } catch (err) {
    console.error("❌ Erreur de connexion MongoDB:", err);
    process.exit(1);
  }
};

module.exports = connectDB;
