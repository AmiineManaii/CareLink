const express = require("express");
require("dotenv").config();
const cors = require("cors");
const http = require("http");
const path = require("path");
const connectDB = require("./config/db");
const socketService = require("./services/socketService");

// Routes
const userRoutes = require("./routes/userRoutes");
const elderRoutes = require("./routes/elderRoutes");
const caregiverRoutes = require("./routes/caregiverRoutes");
const alertRoutes = require("./routes/alertRoutes");
const taskRoutes = require("./routes/taskRoutes");
const medicationRoutes = require("./routes/medicationRoutes");
const contactRoutes = require("./routes/contactRoutes");
const aiRoutes = require("./routes/aiRoutes");

const app = express();
const server = http.createServer(app);

// Initialize DB
connectDB();

// Initialize Sockets
const io = socketService.init(server);
app.set("io", io);

// Middleware
app.use(cors());
app.use((req, res, next) => {
  console.log(`Incoming request: ${req.method} ${req.url}`);
  next();
});
app.use(express.json({ limit: '50mb' }));
app.use('/uploads', express.static(path.join(__dirname, 'uploads')));

// Routes Middleware
app.use("/users", userRoutes);
app.use("/elder", elderRoutes);
app.use("/caregiver", caregiverRoutes);
app.use("/alerts", alertRoutes);
app.use("/medications", medicationRoutes);
app.use("/contacts", contactRoutes);
app.use("/tasks", taskRoutes);
app.use("/ai", aiRoutes);

const PORT = process.env.PORT || 5000;
server.listen(PORT, () => {
  console.log(`🚀 Serveur lancé sur le port ${PORT}`);
});
