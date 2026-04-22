const { Server } = require("socket.io");
const Caregiver = require("../models/caregiver");
const Elder = require("../models/elder");

let io;

const init = (server) => {
  io = new Server(server, {
    cors: { origin: "*", methods: ["GET", "POST"] },
  });

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
            await Elder.findByIdAndUpdate(elderId, { lastActiveAt: now });
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

  return io;
};

const getIO = () => {
  if (!io) {
    throw new Error("Socket.io not initialized!");
  }
  return io;
};

function SendAlertNotif(caregiverId,alert,elderId){
  const io = getIO();
    if (io) {
      io.to(`caregiver:${caregiverId}`).emit("sosAlert", {
        alertId: alert._id.toString(),
        elderId: elderId,
        type: alert.type,
        message: alert.message,
        latitude: alert.latitude,
        longitude: alert.longitude,
        createdAt: alert.createdAt.toISOString(),
      });
    }
}

module.exports = { init, getIO,SendAlertNotif };
