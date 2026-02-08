const express = require("express");
const router = express.Router();
const Elder = require("../models/elder");

function cosineSimilarity(a, b) {
  let dot = 0,
    na = 0,
    nb = 0;
  for (let i = 0; i < a.length; i++) {
    dot += a[i] * b[i];
    na += a[i] * a[i];
    nb += b[i] * b[i];
  }
  const denom = Math.sqrt(na) * Math.sqrt(nb);
  return denom ? dot / denom : 0;
}

function normalize(v) {
  let n = 0;
  for (let i = 0; i < v.length; i++) n += v[i] * v[i];
  n = Math.sqrt(n);
  if (!n) return v.map(() => 0);
  return v.map((x) => x / n);
}

async function generateUniqueCode() {
  while (true) {
    const code = Math.floor(Math.random() * 1000000)
      .toString()
      .padStart(6, "0");
    const exists = await Elder.findOne({ relationCode: code });
    if (!exists) return code;
  }
}

router.post("/signup-face", async (req, res) => {
  try {
    const { embedding, profile = {} } = req.body;
    if (!embedding || !Array.isArray(embedding)) {
      return res.status(400).json({ error: "embedding requis" });
    }

    const elders = await Elder.find({}, { embeddings: 1, relationCode: 1 });
    const threshold = 0.50;
    const embN = normalize(embedding);

    for (const elder of elders) {
      for (const vec of elder.embeddings) {
        const sim = cosineSimilarity(embN, normalize(vec));
        if (sim >= threshold) {
          return res.json({
            elderId: elder._id,
            code: elder.relationCode,
            created: false,
            message: "existing",
          });
        }
      }
    }

    const code = await generateUniqueCode();
    const elder = await Elder.create({
      profile,
      relationCode: code,
      embeddings: [embN],
    });
    return res.json({ elderId: elder._id, code, created: true, message: "new" });
  } catch (e) {
    console.error(e);
    res.status(500).json({ error: "server_error" });
  }
});

router.post("/signin-face", async (req, res) => {
  try {
    const { embedding } = req.body;
    if (!embedding || !Array.isArray(embedding)) {
      return res.status(400).json({ error: "embedding requis" });
    }
    const elders = await Elder.find({}, { embeddings: 1, relationCode: 1 });
    const threshold = 0.50;
    const embN = normalize(embedding);
    let best = { score: 0, elder: null };

    for (const elder of elders) {
      for (const vec of elder.embeddings) {
        const score = cosineSimilarity(embN, normalize(vec));
        if (score > best.score) {
          best = { score, elder };
        }
      }
    }

    if (best.elder && best.score >= threshold) {
      return res.json({
        elderId: best.elder._id,
        code: best.elder.relationCode,
        matched: true,
        message: "recognized",
      });
    }
    return res.json({ elderId: "", code: "", matched: false, message: "no_match" });
  } catch (e) {
    console.error(e);
    res.status(500).json({ error: "server_error" });
  }
});
 
// Mise à jour du profil Elder après signup facial
router.post("/update-profile", async (req, res) => {
  try {
    const { elderId, profile } = req.body;
    if (!elderId || !profile) {
      return res.status(400).json({ error: "elderId et profile requis" });
    }
    const updated = await Elder.findByIdAndUpdate(
      elderId,
      { $set: { profile } },
      { new: true, runValidators: true }
    );
    if (!updated) {
      return res.status(404).json({ error: "elder introuvable" });
    }
    res.json({ ok: true });
  } catch (e) {
    console.error(e);
    res.status(500).json({ error: "server_error" });
  }
});

module.exports = router;
