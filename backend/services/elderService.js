const Elder = require("../models/elder");
const Caregiver = require("../models/caregiver");

class ElderService {
  cosineSimilarity(a, b) {
    let dot = 0, na = 0, nb = 0;
    for (let i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
      na += a[i] * a[i];
      nb += b[i] * b[i];
    }
    const denom = Math.sqrt(na) * Math.sqrt(nb);
    return denom ? dot / denom : 0;
  }

  normalize(v) {
    let n = 0;
    for (let i = 0; i < v.length; i++) n += v[i] * v[i];
    n = Math.sqrt(n);
    if (!n) return v.map(() => 0);
    return v.map((x) => x / n);
  }

  async generateUniqueCode() {
    while (true) {
      const code = Math.floor(Math.random() * 1000000)
        .toString()
        .padStart(6, "0");
      const exists = await Elder.findOne({ relationCode: code });
      if (!exists) return code;
    }
  }

  async signupFace(embedding, profile = {}) {
    const elders = await Elder.find({}, { embeddings: 1, relationCode: 1 });
    const threshold = 0.50;
    const embN = this.normalize(embedding);

    for (const elder of elders) {
      for (const vec of elder.embeddings) {
        const sim = this.cosineSimilarity(embN, this.normalize(vec));
        if (sim >= threshold) {
          return {
            elderId: elder._id,
            code: elder.relationCode,
            created: false,
            message: "existing",
          };
        }
      }
    }

    const code = await this.generateUniqueCode();
    const elder = await Elder.create({
      profile,
      relationCode: code,
      embeddings: [embN],
    });
    return { elderId: elder._id, code, created: true, message: "new" };
  }

  async signinFace(embedding) {
    const elders = await Elder.find({}, { embeddings: 1, relationCode: 1 });
    const threshold = 0.50;
    const embN = this.normalize(embedding);
    let best = { score: 0, elder: null };

    for (const elder of elders) {
      for (const vec of elder.embeddings) {
        const score = this.cosineSimilarity(embN, this.normalize(vec));
        if (score > best.score) {
          best = { score, elder };
        }
      }
    }

    if (best.elder && best.score >= threshold) {
      return {
        elderId: best.elder._id,
        code: best.elder.relationCode,
        matched: true,
        message: "recognized",
      };
    }
    return { elderId: "", code: "", matched: false, message: "no_match" };
  }

  async updateProfile(elderId, profile) {
    const updated = await Elder.findByIdAndUpdate(
      elderId,
      { $set: { profile } },
      { new: true, runValidators: true }
    );
    if (!updated) throw { status: 404, message: "elder introuvable" };
    return { ok: true };
  }

  async verifyCode(code) {
    const elder = await Elder.findOne({ relationCode: code });
    if (elder) {
      return {
        valid: true,
        message: "Code valide",
        elder: {
          firstName: elder.profile?.firstName,
          lastName: elder.profile?.lastName,
        },
      };
    }
    return { valid: false, message: "Code invalide" };
  }

  async getById(id) {
    const elder = await Elder.findById(id);
    if (!elder) throw { status: 404, message: "Elder not found" };
    let online = false;
    let lastActiveAt = elder.lastActiveAt;
    if (lastActiveAt) {
      const diff = Date.now() - new Date(lastActiveAt).getTime();
      online = diff < 60000;
    }
    return {
      _id: elder._id,
      profile: elder.profile,
      relationCode: elder.relationCode,
      embeddings: elder.embeddings,
      lastActiveAt,
      online,
    };
  }

  async heartbeat(id) {
    const elder = await Elder.findByIdAndUpdate(
      id,
      { lastActiveAt: new Date() },
      { new: true }
    );
    if (!elder) throw { status: 404, message: "Elder not found" };
    
    let caregiver = await Caregiver.findOne({ linkedElderId: elder._id });
    let caregiverOnline = false;
    let caregiverLastActiveAt = null;
    
    if (caregiver && caregiver.lastActiveAt) {
      caregiverLastActiveAt = caregiver.lastActiveAt;
      const diff = Date.now() - new Date(caregiver.lastActiveAt).getTime();
      caregiverOnline = diff < 60000;
    }

    let online = false;
    let lastActiveAt = elder.lastActiveAt;
    if (lastActiveAt) {
      const diff = Date.now() - new Date(lastActiveAt).getTime();
      online = diff < 60000;
    }

    return {
      elderId: elder._id,
      online,
      lastActiveAt,
      caregiver: caregiver
        ? {
            caregiverId: caregiver._id,
            online: caregiverOnline,
            lastActiveAt: caregiverLastActiveAt,
          }
        : null,
    };
  }

  async getCaregiver(elderId) {
    const elder = await Elder.findById(elderId);
    if (!elder) throw { status: 404, message: "Elder not found" };

    const caregiver = await Caregiver.findOne({ linkedElderId: elder._id });
    
    let caregiverInfo = null;
    if (caregiver) {
      let online = false;
      if (caregiver.lastActiveAt) {
        const diff = Date.now() - new Date(caregiver.lastActiveAt).getTime();
        online = diff < 60000;
      }
      caregiverInfo = {
        _id: caregiver._id,
        firstName: caregiver.profile?.firstName,
        lastName: caregiver.profile?.lastName,
        phone: caregiver.phone,
        email: caregiver.email,
        online,
        lastActiveAt: caregiver.lastActiveAt,
      };
    }

    return {
      code: elder.relationCode,
      caregiver: caregiverInfo,
    };
  }
}

module.exports = new ElderService();
