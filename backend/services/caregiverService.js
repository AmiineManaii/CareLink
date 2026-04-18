const Caregiver = require("../models/caregiver");
const Elder = require("../models/elder");
const bcrypt = require("bcryptjs");

class CaregiverService {
  async signup(data) {
    const { email, password, phone, gender, elderCode, firstName, lastName } = data;
    const existing = await Caregiver.findOne({ email });
    if (existing) {
      throw { status: 409, message: "email déjà utilisé" };
    }
    const hash = await bcrypt.hash(password, 10);
    let linkedElderId = null;
    if (elderCode) {
      const elder = await Elder.findOne({ relationCode: elderCode });
      if (elder) linkedElderId = elder._id;
    }
    const caregiver = await Caregiver.create({
      email,
      passwordHash: hash,
      phone,
      gender,
      firstName,
      lastName,
      linkedElderId,
    });
    return { caregiverId: caregiver._id, linkedElderId };
  }

  async signin(email, password) {
    const cg = await Caregiver.findOne({ email });
    if (!cg) throw { status: 401, message: "invalid_credentials" };
    const ok = await bcrypt.compare(password, cg.passwordHash);
    if (!ok) throw { status: 401, message: "invalid_credentials" };
    cg.lastActiveAt = new Date();
    await cg.save();
    return { caregiverId: cg._id, linkedElderId: cg.linkedElderId || null };
  }

  async heartbeat(id) {
    const cg = await Caregiver.findByIdAndUpdate(
      id,
      { lastActiveAt: new Date() },
      { new: true }
    );
    if (!cg) throw { status: 404, message: "Caregiver not found" };
    let elder = null;
    let elderOnline = false;
    let elderLastActiveAt = null;
    if (cg.linkedElderId) {
      elder = await Elder.findById(cg.linkedElderId);
      if (elder && elder.lastActiveAt) {
        elderLastActiveAt = elder.lastActiveAt;
        const diff = Date.now() - new Date(elder.lastActiveAt).getTime();
        elderOnline = diff < 60000;
      }
    }
    let online = false;
    let lastActiveAt = cg.lastActiveAt;
    if (lastActiveAt) {
      const diff = Date.now() - new Date(lastActiveAt).getTime();
      online = diff < 60000;
    }
    return {
      caregiverId: cg._id,
      online,
      lastActiveAt,
      elder: elder
        ? {
            elderId: elder._id,
            online: elderOnline,
            lastActiveAt: elderLastActiveAt,
          }
        : null,
    };
  }

  async getById(id) {
    const cg = await Caregiver.findById(id).select("-passwordHash");
    if (!cg) throw { status: 404, message: "Caregiver not found" };
    return cg;
  }

  async update(id, data) {
    const cg = await Caregiver.findByIdAndUpdate(id, data, { new: true }).select("-passwordHash");
    if (!cg) throw { status: 404, message: "Caregiver not found" };
    return cg;
  }
}

module.exports = new CaregiverService();
