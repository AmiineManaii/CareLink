const express = require("express");
const mongoose = require("mongoose");
const cors = require("cors");
const http = require("http");
const { Server } = require("socket.io");
require("dotenv").config();
const userRoutes = require("./routes/userRoutes");
const elderRoutes = require("./routes/elderRoutes");
const caregiverRoutes = require("./routes/caregiverRoutes");
const alertRoutes = require("./routes/alertRoutes");
const Caregiver = require("./models/caregiver");
const Alert = require("./models/alert");

const app = express();
const server = http.createServer(app);
const io = new Server(server, {
  cors: { origin: "*", methods: ["GET", "POST"] },
});

app.use(cors());
app.use(express.json());
app.use("/users", userRoutes);
app.use("/elder", elderRoutes);
app.use("/caregiver", caregiverRoutes);
app.use("/alerts", alertRoutes);

const mongoUri = process.env.MONGODB_URI || "mongodb://127.0.0.1:27017/flutterDB";
mongoose
  .connect(mongoUri)
  .then(() => console.log("✅ MongoDB connecté"))
  .catch((err) => console.log(err));

io.on("connection", (socket) => {
  console.log("🔌 Socket connecté", socket.id);

  socket.on("registerCaregiver", async ({ caregiverId }) => {
    socket.data.caregiverId = caregiverId;
    try {
      const cg = await Caregiver.findByIdAndUpdate(
        caregiverId,
        { lastActiveAt: new Date() },
        { new: true }
      );
      if (cg && cg.linkedElderId) {
        const room = `elder:${cg.linkedElderId.toString()}`;
        socket.join(room);
        io.to(room).emit("caregiverPresence", {
          online: true,
          lastActiveAt: new Date().toISOString(),
          caregiverId: cg._id.toString(),
        });
      }
    } catch (e) {
      console.error(e);
    }
  });

  socket.on("registerElder", async ({ elderId }) => {
    if (!elderId) return;
    socket.data.elderId = elderId;
    const room = `elder:${elderId}`;
    socket.join(room);
  });

  socket.on("heartbeat", async () => {
    const id = socket.data.caregiverId;
    if (!id) return;
    try {
      const cg = await Caregiver.findByIdAndUpdate(
        id,
        { lastActiveAt: new Date() },
        { new: true }
      );
      if (cg && cg.linkedElderId) {
        const room = `elder:${cg.linkedElderId.toString()}`;
        io.to(room).emit("caregiverPresence", {
          online: true,
          lastActiveAt: new Date().toISOString(),
          caregiverId: cg._id.toString(),
        });
      }
    } catch (e) {
      console.error(e);
    }
  });

  socket.on("disconnect", () => {
    console.log("🔌 Socket déconnecté", socket.id);
  });
});

const port = process.env.PORT || 5000;
server.listen(port, "0.0.0.0", () => {
  console.log(`🚀 Serveur lancé sur http://localhost:${port}`);
});
