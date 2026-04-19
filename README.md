# 🏥 CareLink — Plateforme d'assistance pour personnes âgées

<div align="center">

![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter)
![Node.js](https://img.shields.io/badge/Node.js-20.x-339933?logo=node.js)
![MongoDB](https://img.shields.io/badge/MongoDB-Atlas-47A248?logo=mongodb)
![Socket.io](https://img.shields.io/badge/Socket.io-4.x-010101?logo=socket.io)
![Render](https://img.shields.io/badge/Deploy-Render-46E3B7?logo=render)
![Cloudinary](https://img.shields.io/badge/Media-Cloudinary-3448C5?logo=cloudinary)

**Application mobile Flutter double interface (Senior + Aidant) connectée en temps réel**

</div>

---

## 📋 Table des matières

- [Présentation](#-présentation)
- [Problématique](#-problématique)
- [Solution proposée](#-solution-proposée)
- [Architecture](#-architecture)
- [Stack technologique](#-stack-technologique)
- [Fonctionnalités](#-fonctionnalités)
- [Infrastructure & Déploiement](#-infrastructure--déploiement)
- [Installation](#-installation)
- [Variables d'environnement](#-variables-denvironnement)
- [Structure du projet](#-structure-du-projet)

---

## 🎯 Présentation

**CareLink** est une application mobile conçue pour améliorer la sécurité et l'autonomie des personnes âgées vivant seules, tout en donnant aux aidants (famille, soignants) une visibilité en temps réel sur leur bien-être.

L'application propose **deux interfaces distinctes** :
- 👴 **Interface Senior** — simplifiée, accessible, grande typographie
- 👩‍⚕️ **Interface Aidant** — dashboard de surveillance et gestion

---

## ❗ Problématique

Les personnes âgées vivant seules font face à trois défis majeurs :

| Problème | Impact |
|----------|--------|
| **Isolement et difficultés de suivi** | L'aidant ne peut pas être présent 24h/24. Les signaux de détresse passent inaperçus. |
| **Alertes d'urgence tardives** | En cas de chute ou malaise, l'absence de système réactif aggrave les conséquences médicales. |
| **Oublis de médicaments** | La gestion de traitements complexes représente un risque sanitaire majeur pour les seniors. |

---

## 💡 Solution proposée

CareLink répond à ces problèmes par une combinaison de technologies mobiles, IA embarquée et communication en temps réel :

- **Authentification sans friction** → Reconnaissance faciale (pas de mot de passe)
- **Alertes automatisées multi-canaux** → SOS bouton + détection de chute + SMS + email
- **Rappels médicaments intelligents** → Notifications natives + confirmation vocale
- **IA d'identification d'objets** → Aide visuelle pour les seniors malvoyants
- **Présence temps réel** → Socket.io entre senior et aidant (heartbeat 30s)

---

## 🏗️ Architecture

### Vue d'ensemble

```
┌─────────────────────────────────────────────────────────────┐
│                     CLIENT FLUTTER                           │
│  ┌──────────┐ ┌───────────┐ ┌──────────┐ ┌──────────────┐  │
│  │Face Auth │ │Socket.io  │ │Camera/GPS│ │TTS / STT     │  │
│  │(TFLite)  │ │Client     │ │          │ │Notifications │  │
│  └──────────┘ └───────────┘ └──────────┘ └──────────────┘  │
└────────────────────────┬────────────────────────────────────┘
                         │ HTTPS + WebSocket
┌────────────────────────▼────────────────────────────────────┐
│              BACKEND — Node.js / Express                     │
│              Déployé sur Render.com                          │
│  ┌──────────┐ ┌───────────┐ ┌──────────┐ ┌──────────────┐  │
│  │REST API  │ │Socket.io  │ │Multer    │ │bcryptjs      │  │
│  │(Express) │ │Server     │ │Upload    │ │Auth          │  │
│  └──────────┘ └───────────┘ └──────────┘ └──────────────┘  │
└──────┬──────────────┬────────────┬─────────────┬────────────┘
       │              │            │             │
       ▼              ▼            ▼             ▼
┌───────────┐ ┌────────────┐ ┌─────────┐ ┌──────────────┐
│ MongoDB   │ │ Cloudinary │ │ Ollama  │ │ SMTP Gmail   │
│  Atlas    │ │ CDN        │ │ + ngrok │ │ Alertes SOS  │
│ (données) │ │ (médias)   │ │ (IA VL) │ │              │
└───────────┘ └────────────┘ └─────────┘ └──────────────┘
```

### Flow d'authentification faciale

```
App Flutter → Caméra → ML Kit (détection visage)
           → Crop + Resize 112×112
           → MobileFaceNet TFLite (embedding 192D)
           → Normalisation cosinus
           → POST /elder/signup-face ou /elder/signin-face
           → Backend (similarité cosinus ≥ 0.50)
           → Résultat + elderId
```

### Flow d'alerte SOS

```
Senior appuie SOS
    ├── GPS Geolocator → Position lat/lng
    ├── POST /alerts/create → MongoDB (alert)
    ├── Socket.io emit → Aidant (notification temps réel)
    ├── SMTP Gmail → Email aidant
    └── SMS (fallback sans réseau) → MethodChannel Android
```

### Flow IA d'identification d'objets

```
Senior prend une photo
    ├── Base64 → POST /ai/analyze-image
    ├── Backend → Ollama (Qwen3-VL:2b) via ngrok tunnel
    ├── Résultat asynchrone → Socket.io emit → elder:ID
    └── [Si Ollama indisponible] → TFLite local (fallback)
                                → ML Kit Object Detection
```

---

## 🛠️ Stack technologique

### Frontend — Flutter

| Technologie | Usage |
|-------------|-------|
| Flutter 3.x / Dart | Framework UI cross-platform |
| `tflite_flutter` | Inférence modèle MobileFaceNet |
| `google_mlkit_face_detection` | Détection de visage en temps réel |
| `google_mlkit_object_detection` | Détection d'objets locale |
| `socket_io_client` | Communication WebSocket temps réel |
| `geolocator` | Géolocalisation GPS |
| `flutter_tts` | Text-to-Speech (français) |
| `speech_to_text` | Speech-to-Text |
| `flutter_foreground_task` | Service de détection de chute en background |
| `flutter_map` + `latlong2` | Cartographie OpenStreetMap |
| `camera` | Accès caméra native |
| `record` + `audioplayers` | Enregistrement et lecture audio |
| `shared_preferences` | Stockage local (session) |
| `image_picker` | Sélection d'images |

### Backend — Node.js

| Technologie | Usage |
|-------------|-------|
| Node.js 20 + Express 5 | Serveur REST API |
| Socket.io 4.x | WebSocket temps réel |
| Mongoose + MongoDB | ODM + base de données |
| Multer (memoryStorage) | Upload de fichiers en mémoire |
| Cloudinary SDK | Upload et CDN médias |
| bcryptjs | Hashage mots de passe |
| axios | Appels API externes (Ollama) |
| nodemon | Hot-reload développement |

### Services externes

| Service | Usage | Config |
|---------|-------|--------|
| **MongoDB Atlas** | Base de données cloud | `MONGODB_URI` |
| **Cloudinary** | CDN images, audio médicaments, photos | `CLOUDINARY_*` |
| **Render.com** | Hébergement backend Node.js | Auto-deploy Git |
| **Ollama + ngrok** | IA locale Qwen3-VL:2b (identification objets) | `OLLAMA_URL` |
| **SMTP Gmail** | Envoi emails alertes SOS | `SMTP_USER/PASS/TO` |
| **OpenStreetMap** | Tuiles cartographiques (flutter_map) | Gratuit |

---

## ✨ Fonctionnalités

### Interface Senior 👴

- 🔐 **Authentification faciale** — Inscription et connexion sans mot de passe
- 🆘 **Bouton SOS** — Grande zone tactile, envoi d'alerte multi-canal
- 💊 **Médicaments du jour** — Liste filtrée + confirmation vocale/texte
- 📞 **Contacts rapides** — Appel, vidéo, message vocal
- 🔍 **Identification d'objets** — Photo → IA → résultat vocal
- 📄 **Scanner document (OCR)** — Lecture d'ordonnances via ML Kit
- 🎤 **Dictée vocale** — Speech-to-Text français
- 📋 **Tâches du jour** — Agenda avec rappels natifs
- 🧠 **Jeu de mémoire** — Stimulation cognitive (Memory couleurs)
- 🗺️ **Historique SOS** — Liste des alertes avec carte GPS

### Interface Aidant 👩‍⚕️

- 📊 **Dashboard temps réel** — Statut en ligne/hors ligne du senior
- 🔔 **Alertes SOS** — Réception immédiate avec carte de localisation
- 💊 **Gestion médicaments** — CRUD complet + photos + historique des prises
- 📋 **Suivi des tâches** — Ajout/suppression/complétion pour le senior
- 📞 **Gestion contacts** — Contacts d'urgence du senior
- 👤 **Profil senior** — Modification des informations et photo
- 🔗 **Liaison par code** — Code à 6 chiffres pour lier aidant ↔ senior

---

## 🌐 Infrastructure & Déploiement

### Backend — Render.com

Le backend Node.js est déployé sur **Render.com** (plan gratuit).

```
https://votre-app.onrender.com
```

> ⚠️ Le plan gratuit met l'instance en veille après 15 min d'inactivité. Le premier appel peut prendre ~30s.

### IA — Ollama + ngrok

Le modèle Qwen3-VL:2b tourne en local et est exposé via ngrok :

```bash
# Lancer Ollama
ollama run qwen3-vl:2b-instruct-q4_K_M

# Exposer via ngrok
ngrok http 11434

# Copier l'URL dans .env
OLLAMA_URL=https://xxxxx.ngrok-free.app/api/chat
```

### Médias — Cloudinary

Photos de profil, photos médicaments et messages vocaux sont uploadés sur Cloudinary via `multer memoryStorage` (pas de fichier temporaire).

### Base de données — MongoDB Atlas

```
MONGODB_URI=mongodb+srv://user:pass@cluster.mongodb.net/carelink
```

---

## 🚀 Installation

### Prérequis

- Node.js 20+
- Flutter 3.x
- MongoDB Atlas (compte gratuit)
- Cloudinary (compte gratuit)
- Ollama installé localement (optionnel)

### Backend

```bash
# Cloner le dépôt
git clone https://github.com/AmiineManaii/carelink.git
cd carelink/backend

# Installer les dépendances
npm install

# Configurer les variables d'environnement
cp .env.example .env
# Éditer .env avec vos clés

# Développement
npm run dev

# Production
npm start
```

### Application Flutter

```bash
cd carelink

# Installer les dépendances
flutter pub get

# Configurer l'environnement
cp assets/.env.example assets/.env
# Éditer avec l'URL du backend

# Lancer sur device/émulateur
flutter run
```

### Modèles IA requis

Placer dans `assets/` :
- `mobilefacenet.tflite` — Modèle de reconnaissance faciale (192D embeddings)
- `classifier.tflite` — Classifieur d'objets (EfficientNet ou MobileNet)
- `labels.txt` — Labels correspondants au classifieur

---

## 🔧 Variables d'environnement

### Backend `.env`

```env
PORT=5000
MONGODB_URI=mongodb+srv://...

CLOUDINARY_NAME=votre_cloud_name
CLOUDINARY_API_KEY=votre_api_key
CLOUDINARY_API_SECRET=votre_api_secret

OLLAMA_URL=https://xxxxx.ngrok-free.app/api/chat

SMTP_USER=votre@gmail.com
SMTP_PASS=votre_app_password
SMTP_TO=destinataire@email.com
```

### Flutter `assets/.env`

```env
BACKEND_URL=https://votre-app.onrender.com
SMS_TO=+21600000000
```

---

## 📁 Structure du projet

```
carelink/
├── backend/
│   ├── config/
│   │   └── db.js                  # Connexion MongoDB
│   ├── controllers/
│   │   ├── aiController.js        # Contrôleur IA
│   │   ├── caregiverController.js # Contrôleur aidant
│   │   └── elderController.js     # Contrôleur senior
│   ├── models/
│   │   ├── alert.js               # Modèle alerte
│   │   ├── caregiver.js           # Modèle aidant
│   │   ├── contact.js             # Modèle contact
│   │   ├── elder.js               # Modèle senior
│   │   ├── medication.js          # Modèle médicament
│   │   ├── medicationLog.js       # Historique prises
│   │   └── task.js                # Modèle tâche
│   ├── routes/
│   │   ├── aiRoutes.js
│   │   ├── alertRoutes.js
│   │   ├── caregiverRoutes.js
│   │   ├── elderRoutes.js
│   │   ├── medicationRoutes.js
│   │   └── taskRoutes.js
│   ├── services/
│   │   ├── aiService.js           # Service Ollama (IA)
│   │   ├── caregiverService.js    # Logique métier aidant
│   │   ├── elderService.js        # Auth faciale + logique senior
│   │   └── socketService.js       # WebSocket temps réel
│   ├── utils/
│   │   └── uploadToCloudinary.js  # Helper upload Cloudinary
│   ├── server.js                  # Point d'entrée
│   └── package.json
│
└── lib/                           # Application Flutter
    ├── main.dart                  # Point d'entrée + routing
    ├── models/
    │   ├── contact.dart
    │   ├── medication.dart
    │   └── (...)
    ├── screens/
    │   ├── elder/                 # Écrans interface senior
    │   │   ├── auth/              # Signup/login facial
    │   │   ├── accessibility_screen.dart  # IA + OCR + TTS
    │   │   ├── daily_tasks_screen.dart
    │   │   ├── medications_screen.dart
    │   │   └── (...)
    │   └── caregiver/             # Écrans interface aidant
    │       ├── auth/
    │       ├── medications/
    │       ├── profile/
    │       └── (...)
    ├── services/
    │   ├── api_service.dart       # Client HTTP centralisé
    │   ├── auth/                  # Face detection + recognition
    │   ├── home_service.dart      # Scheduling tâches/médocs
    │   ├── location_service.dart  # GPS
    │   ├── ml/                    # TFLite + ML Kit
    │   ├── presence_service.dart  # Socket.io client
    │   └── sos_service.dart       # Logique SOS multi-canal
    ├── utils/
    │   ├── face_storage.dart      # SharedPreferences session
    │   ├── face_utils.dart        # Crop/resize/convert images
    │   └── label_translations.dart # Traductions FR des labels IA
    └── widgets/                   # Composants réutilisables
        ├── common/
        └── elder/
```

---

## 🔐 Sécurité

- Les mots de passe aidants sont hashés avec **bcryptjs** (salt 10)
- Les embeddings faciaux sont normalisés et stockés côté serveur (MongoDB)
- Les uploads utilisent **memoryStorage** (pas de fichier temporaire sur disque)
- Les communications utilisent **HTTPS** (Render) et **WSS** (WebSocket sécurisé)
- Le tunnel ngrok Ollama est éphémère et sans credentials publics

---

## 📄 Licence

MIT — Projet académique / pédagogique.

---

<div align="center">
Développé avec ❤️ pour améliorer la qualité de vie des personnes âgées
</div>