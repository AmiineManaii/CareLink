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
const Elder = require("./models/elder");
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
  socket.data.lastActivityCheckAt = Date.now();

  socket.on("elderHeartbeat", async ({ elderId }) => {
    try {
      if (!elderId) return;
      const now = new Date();
      await Elder.findByIdAndUpdate(
        elderId,
        { lastActiveAt: now },
        { new: true }
      );
      const caregivers = await Caregiver.find({ linkedElderId: elderId });
      caregivers.forEach((cg) => {
        io.to(`caregiver:${cg._id.toString()}`).emit("elderPresence", {
          online: true,
          lastActiveAt: now.toISOString(),
          elderId: elderId.toString(),
        });
      });
    } catch (e) {
      console.error(e);
    }
  });

  socket.on("registerCaregiver", async ({ caregiverId }) => {
    socket.data.caregiverId = caregiverId;
    try {
      const cg = await Caregiver.findByIdAndUpdate(
        caregiverId,
        { lastActiveAt: new Date() },
        { new: true }
      );
      if (cg && cg.linkedElderId) {
        const elderRoom = `elder:${cg.linkedElderId.toString()}`;
        const caregiverRoom = `caregiver:${cg._id.toString()}`;
        socket.join(elderRoom);
        socket.join(caregiverRoom);

        io.to(elderRoom).emit("caregiverPresence", {
          online: true,
          lastActiveAt: new Date().toISOString(),
          caregiverId: cg._id.toString(),
        });

        const elder = await Elder.findById(cg.linkedElderId);

        // ✅ FIX: utiliser lastActiveAt au lieu de vérifier la room
        const now = Date.now();
        const elderOnline =
          elder && elder.lastActiveAt
            ? now - new Date(elder.lastActiveAt).getTime() < 60000
            : false;

        io.to(caregiverRoom).emit("elderPresence", {
          online: elderOnline,
          lastActiveAt:
            elder && elder.lastActiveAt
              ? elder.lastActiveAt.toISOString()
              : null,
          elderId: cg.linkedElderId.toString(),
        });
      }
    } catch (e) {
      console.error(e);
    }
  });

  socket.on("registerElder", async ({ elderId }) => {
    try {
      if (!elderId) return;
      socket.data.elderId = elderId;
      const room = `elder:${elderId}`;
      socket.join(room);
      const now = new Date();
      await Elder.findByIdAndUpdate(
        elderId,
        { lastActiveAt: now },
        { new: true }
      );
      const caregivers = await Caregiver.find({ linkedElderId: elderId });
      caregivers.forEach((cg) => {
        io.to(`caregiver:${cg._id.toString()}`).emit("elderPresence", {
          online: true,
          lastActiveAt: now.toISOString(),
          elderId: elderId.toString(),
        });
        const caregiverOnline = cg.lastActiveAt
          ? now - new Date(cg.lastActiveAt).getTime() < 60000
          : false;
        if (caregiverOnline) {
          io.to(`caregiver:${cg._id.toString()}`).emit("pairStatus", {
            caregiverId: cg._id.toString(),
            elderId: elderId.toString(),
            caregiverOnline,
            elderOnline: true,
          });
        }
      });
    } catch (e) {
      console.error(e);
    }
  });

  socket.on("caregiverHeartbeat", async () => {
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
        const elder = await Elder.findById(cg.linkedElderId);
        const now = Date.now();
        let elderOnline = false;
        if (elder && elder.lastActiveAt) {
          const diff = now - new Date(elder.lastActiveAt).getTime();
          elderOnline = diff < 60000;
        }
        const caregiverOnline = true;
        if (elderOnline) {
          io.to(`caregiver:${cg._id.toString()}`).emit("pairStatus", {
            caregiverId: cg._id.toString(),
            elderId: cg.linkedElderId.toString(),
            caregiverOnline,
            elderOnline,
          });
        }
      }
    } catch (e) {
      console.error(e);
    }
  });

  socket.on("disconnect", async () => {
    console.log("🔌 Socket déconnecté", socket.id);
    const elderId = socket.data.elderId;
    if (elderId) {
      try {
        const room = `elder:${elderId}`;
        const sockets = io.sockets.adapter.rooms.get(room);
        const hasOtherSockets = sockets && sockets.size > 0;
        if (!hasOtherSockets) {
          const now = new Date();
          await Elder.findByIdAndUpdate(
            elderId,
            { lastActiveAt: now },
            { new: true }
          );
          const caregivers = await Caregiver.find({ linkedElderId: elderId });
          caregivers.forEach((cg) => {
            io.to(`caregiver:${cg._id.toString()}`).emit("elderPresence", {
              online: false,
              lastActiveAt: now.toISOString(),
              elderId: elderId.toString(),
            });
          });
        }
      } catch (e) {
        console.error(e);
      }
    }
  });
});

setInterval(async () => {
  try {
    const elders = await Elder.find({ lastActiveAt: { $ne: null } });
    const now = Date.now();
    for (const elder of elders) {
      const diff = now - new Date(elder.lastActiveAt).getTime();
      if (diff > 60000) {
        const caregivers = await Caregiver.find({ linkedElderId: elder._id });
        caregivers.forEach((cg) => {
          io.to(`caregiver:${cg._id.toString()}`).emit("elderPresence", {
            online: false,
            lastActiveAt: elder.lastActiveAt.toISOString(),
            elderId: elder._id.toString(),
          });
        });
      }
    }
    const caregivers = await Caregiver.find({ lastActiveAt: { $ne: null } });
    for (const cg of caregivers) {
      const diff = now - new Date(cg.lastActiveAt).getTime();
      if (diff > 60000 && cg.linkedElderId) {
        const room = `elder:${cg.linkedElderId.toString()}`;
        io.to(room).emit("caregiverPresence", {
          online: false,
          lastActiveAt: cg.lastActiveAt.toISOString(),
          caregiverId: cg._id.toString(),
        });
      }
    }
  } catch (e) {
    console.error(e);
  }
}, 10000);

const port = process.env.PORT || 5000;
server.listen(port, "0.0.0.0", () => {
  console.log(`🚀 Serveur lancé sur http://localhost:${port}`);
});
