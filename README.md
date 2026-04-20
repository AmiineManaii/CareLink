# CareLink — Documentation Technique Complète

> Application mobile d'assistance aux personnes âgées et à leurs aidants, avec reconnaissance faciale, détection de chutes, rappels médicaments, alertes SOS et IA embarquée.

---

## Table des matières

1. [Présentation du projet](#1-présentation-du-projet)
2. [Problématique](#2-problématique)
3. [Solution proposée](#3-solution-proposée)
4. [Architecture globale — N-Tiers](#4-architecture-globale--n-tiers)
5. [Infrastructure](#5-infrastructure)
6. [Architecture technique détaillée](#6-architecture-technique-détaillée)
7. [Patterns architecturaux](#7-patterns-architecturaux)
8. [Design Patterns utilisés](#8-design-patterns-utilisés)
9. [Modules fonctionnels](#9-modules-fonctionnels)
10. [Flux de données](#10-flux-de-données)
11. [Workflows complexes — Détail complet](#11-workflows-complexes--détail-complet)
    - [WF-01 — Inscription faciale du senior](#wf-01--inscription-et-authentification-faciale-du-senior)
    - [WF-02 — Connexion faciale](#wf-02--connexion-faciale-du-senior)
    - [WF-03 — Inscription aidant et liaison senior](#wf-03--inscription-de-laidant-et-liaison-avec-un-senior)
    - [WF-04 — Pipeline SOS complet](#wf-04--pipeline-sos-complet-bouton--détection-de-chute)
    - [WF-05 — Identification d'objets par IA](#wf-05--identification-dobjets-par-ia-pipeline-hybride)
    - [WF-06 — Cycle de vie médicament](#wf-06--rappels-et-confirmation-de-médicaments)
    - [WF-07 — Présence temps réel WebSocket](#wf-07--présence-en-temps-réel-websocket-bidirectionnel)
    - [WF-08 — Détection de chute](#wf-08--détection-de-chute-service-android-natif--flutter)
    - [WF-09 — OCR et lecture de documents](#wf-09--ocr-et-lecture-de-documents)
    - [WF-10 — Tâches quotidiennes](#wf-10--gestion-des-tâches-quotidiennes)
12. [Sécurité](#12-sécurité)
13. [Déploiement](#13-déploiement)
14. [Installation & Configuration](#14-installation--configuration)

---

## 1. Présentation du projet

**CareLink** est une application mobile cross-platform (Android/iOS) conçue pour faciliter la surveillance et l'assistance quotidienne des personnes âgées. Elle repose sur deux interfaces distinctes :

- **Application Senior** : interface épurée, grandes polices, bouton SOS physique, rappels médicaments vocaux, identification d'objets par IA.
- **Application Aidant** : tableau de bord de suivi, gestion des médicaments, tâches, contacts d'urgence, historique des alertes SOS avec cartographie.

---

## 2. Problématique

Les personnes âgées vivant seules ou semi-autonomes font face à plusieurs risques quotidiens :

- **Chutes non détectées** : absence de signal d'alarme automatique en cas de chute.
- **Oublis de médicaments** : mauvaise observance thérapeutique, risque de surdosage ou de sous-dosage.
- **Isolement** : difficulté à contacter les proches ou services d'urgence.
- **Difficultés cognitives** : incapacité à identifier des objets ou lire des documents (ordonnances, courriers).
- **Charge de l'aidant** : manque de visibilité en temps réel sur l'état de la personne accompagnée.
- **Authentification complexe** : les mots de passe sont difficiles à mémoriser pour des personnes âgées.

---

## 3. Solution proposée

CareLink répond à ces problématiques par un ensemble de fonctionnalités intégrées :

| Problème | Solution CareLink |
|---|---|
| Chutes non détectées | Détection de chutes via accéléromètre (service Android natif) + envoi SOS automatique |
| Oublis de médicaments | Rappels planifiés avec confirmation vocale ou textuelle |
| Isolement | Bouton SOS géolocalisé, SMS de secours sans Internet, alerte email |
| Difficultés cognitives | IA d'identification d'objets (Ollama + TFLite), OCR de documents, TTS/STT |
| Authentification | Reconnaissance faciale via MobileFaceNet (TFLite) |
| Charge de l'aidant | Tableau de bord temps réel, présence en ligne via WebSocket, historique complet |

---

## 4. Architecture globale — N-Tiers

CareLink suit une **architecture 3-tiers** classique, étendue d'une couche IA on-device.

```
┌─────────────────────────────────────────────────────────────┐
│                   TIER 1 — Présentation                     │
│              Application Flutter (Mobile)                   │
│   ┌──────────────────┐      ┌──────────────────────────┐   │
│   │  App Senior      │      │  App Aidant              │   │
│   │  (elderly_nav)   │      │  (caregiver_nav)         │   │
│   └──────────────────┘      └──────────────────────────┘   │
└──────────────────────┬──────────────────────────────────────┘
                       │  HTTP/REST + WebSocket (Socket.IO)
┌──────────────────────▼──────────────────────────────────────┐
│                   TIER 2 — Logique métier                   │
│              Backend Node.js / Express.js                   │
│   ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐  │
│   │  Elder   │  │Caregiver │  │  Alert   │  │   AI     │  │
│   │ Service  │  │ Service  │  │  Routes  │  │ Service  │  │
│   └──────────┘  └──────────┘  └──────────┘  └──────────┘  │
│   ┌──────────┐  ┌──────────┐  ┌──────────┐                 │
│   │  Task    │  │   Med.   │  │ Contact  │                 │
│   │  Routes  │  │  Routes  │  │  Routes  │                 │
│   └──────────┘  └──────────┘  └──────────┘                 │
│                  Socket.IO Server                           │
└──────────────────────┬──────────────────────────────────────┘
                       │  Mongoose ODM
┌──────────────────────▼──────────────────────────────────────┐
│                   TIER 3 — Données                          │
│                    MongoDB Atlas                            │
│   Collections: elders, caregivers, alerts, medications,    │
│   medicationlogs, tasks, contacts, users                   │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│             TIER 4 (étendu) — IA On-Device / On-Premise     │
│   ┌──────────────────────────┐  ┌──────────────────────┐   │
│   │  Ollama (local/serveur)  │  │  TFLite on-device    │   │
│   │  Modèle: qwen3-vl:2b     │  │  MobileFaceNet 112px │   │
│   │  Vision + Langage        │  │  Classifier COCO     │   │
│   └──────────────────────────┘  │  ML Kit Object Det.  │   │
│                                  └──────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

---

## 5. Infrastructure

### 5.1 Backend

| Composant | Technologie | Rôle |
|---|---|---|
| Serveur HTTP | Node.js 18+ / Express.js | API REST |
| Temps réel | Socket.IO | Présence, notifications push IA |
| ODM | Mongoose 7+ | Modélisation et accès MongoDB |
| Upload fichiers | Multer (memoryStorage) | Traitement en mémoire, pas de disque local |
| Stockage fichiers | Cloudinary CDN | Photos profil, médicaments, audio vocal |
| Authentification | bcryptjs | Hachage mots de passe aidants |
| HTTP interne | Axios | Appels vers Ollama |
| Variables d'env. | dotenv | Configuration secrets |

### 5.2 Base de données

| Aspect | Détail |
|---|---|
| Moteur | MongoDB (compatible Atlas) |
| Schéma | Document-oriented, schémas Mongoose |
| Indexation | `email` (unique), `relationCode` (unique) sur Elder |
| Relations | Références ObjectId entre collections (linkedElderId, elderId, caregiverId) |

**Collections principales :**

```
elders            → profil, embeddings faciaux, code de liaison
caregivers        → email, passwordHash, linkedElderId
alerts            → elderId, caregiverId, type, GPS, read
medications       → nom, dosage, fréquence, jours, heures, elderId
medicationlogs    → prise confirmée, statut, note, audioUrl
tasks             → titre, heure, date, isCompleted, elderId
contacts          → nom, téléphone, relation, elderId, caregiverId
```

### 5.3 Frontend Mobile

| Composant | Technologie |
|---|---|
| Framework | Flutter 3.x (Dart) |
| Navigation | MaterialApp + Navigator.push/pop |
| État | StatefulWidget + setState (local state) |
| Stockage local | SharedPreferences (session, embedding) |
| HTTP | package:http |
| WebSocket | socket_io_client |
| IA on-device | tflite_flutter, google_mlkit_object_detection, google_mlkit_text_recognition |
| Biométrie | google_mlkit_face_detection + MobileFaceNet TFLite |
| Caméra | camera, image_picker |
| Audio | record, audioplayers, flutter_tts, speech_to_text |
| Cartes | flutter_map + OpenStreetMap |
| Géolocalisation | geolocator |
| Notifications | MethodChannel natif Android (fall_channel) |
| Service Android | FlutterForegroundTask |

### 5.4 IA & Machine Learning

| Modèle | Localisation | Usage |
|---|---|---|
| MobileFaceNet | On-device TFLite (112×112) | Reconnaissance faciale, embedding 192D |
| qwen3-vl:2b-instruct-q4_K_M | Ollama (serveur local/cloud) | Identification d'objets par vision |
| Classifier COCO | On-device TFLite | Fallback classification d'objets |
| ML Kit Object Detector | On-device (Google MLKit) | Détection bounding boxes |
| ML Kit Text Recognizer | On-device (Google MLKit) | OCR de documents (latin) |

### 5.5 Services externes

| Service | Usage |
|---|---|
| Cloudinary | CDN photos + audio (upload via Stream) |
| Gmail SMTP | Envoi d'emails SOS |
| OpenStreetMap / flutter_map | Affichage des cartes SOS |
| Ollama | Inférence IA vision locale ou auto-hébergée |

---

## 6. Architecture technique détaillée

### 6.1 Structure du backend

```
backend/
├── server.js                  # Point d'entrée, configuration Express + Socket.IO
├── config/
│   └── db.js                  # Connexion MongoDB (connectDB)
├── models/                    # Schémas Mongoose
│   ├── elder.js
│   ├── caregiver.js
│   ├── alert.js
│   ├── medication.js
│   ├── medicationLog.js
│   ├── task.js
│   ├── contact.js
│   └── user.js
├── controllers/               # Couche contrôleur (délègue aux services)
│   ├── elderController.js
│   ├── caregiverController.js
│   └── aiController.js
├── services/                  # Logique métier pure
│   ├── elderService.js        # Cosine similarity, gestion embeddings
│   ├── caregiverService.js    # Auth, heartbeat
│   ├── aiService.js           # Appel Ollama + emission Socket.IO
│   └── socketService.js       # Gestion des rooms et événements temps réel
├── routes/                    # Déclaration des routes Express
│   ├── elderRoutes.js
│   ├── caregiverRoutes.js
│   ├── alertRoutes.js
│   ├── medicationRoutes.js
│   ├── taskRoutes.js
│   ├── contactRoutes.js
│   ├── aiRoutes.js
│   └── userRoutes.js
├── middleware/
│   └── asyncHandler.js        # Wrapper try/catch pour les routes async
└── utils/
    └── uploadToCloudinary.js  # Upload via stream (memoryStorage)
```

### 6.2 Structure Flutter

```
lib/
├── main.dart                      # Point d'entrée, StartupGate, AuthLandingScreen
├── models/                        # DTOs Dart
│   ├── medication.dart
│   └── contact.dart
├── services/                      # Couche service Flutter
│   ├── api_service.dart           # Singleton — tous les appels HTTP
│   ├── presence_service.dart      # Singleton — Socket.IO + heartbeat
│   ├── home_service.dart          # Orchestration démarrage (médicaments, tâches)
│   ├── location_service.dart      # GPS en arrière-plan
│   ├── sos_service.dart           # SOS : API + email + SMS fallback
│   ├── medication_reminder_service.dart  # Planification notifications
│   ├── permission_service.dart    # Demande de permissions Android/iOS
│   ├── auth/
│   │   ├── face_detector_service.dart
│   │   ├── face_recognition_service.dart  # TFLite MobileFaceNet
│   │   └── face_compare_service.dart
│   └── ml/
│       └── ml_service.dart        # TFLite Classifier + ML Kit
├── screens/
│   ├── elder/                     # Interface personne âgée
│   │   ├── auth/                  # Signup/Login facial
│   │   ├── navigation/
│   │   ├── home_screen.dart
│   │   ├── medications_screen.dart
│   │   ├── contacts_screen.dart
│   │   ├── accessibility_screen.dart  # OCR, TTS, STT, IA objets
│   │   ├── daily_tasks_screen.dart
│   │   ├── alerts_screen.dart
│   │   └── color_memory_game.dart
│   └── caregiver/                 # Interface aidant
│       ├── auth/
│       ├── caregiver_home_screen.dart
│       ├── caregiver_alerts_screen.dart
│       ├── caregiver_tasks_screen.dart
│       ├── caregiver_contacts_screen.dart
│       ├── medications/
│       └── profile/
├── utils/
│   ├── face_storage.dart          # Singleton SharedPreferences (session)
│   ├── face_utils.dart            # Utilitaires caméra/image
│   ├── label_translations.dart    # Dictionnaire EN→FR pour labels IA
│   ├── fonctions_utils.dart       # Utilitaires partagés (SOS, SMS, SnackBar)
│   ├── fall_detection_manager.dart
│   └── fall_detection_handler.dart
└── widgets/
    ├── common/                    # Widgets réutilisables
    │   ├── custom_app_bar.dart
    │   ├── quick_action_card.dart
    │   ├── sos_button.dart
    │   ├── sos_mini_map.dart
    │   ├── feature_card.dart
    │   ├── info_card.dart
    │   ├── contact_widgets.dart
    │   └── medication_reminder_card.dart
    ├── auth/
    │   └── face_painter.dart      # CustomPainter overlay caméra
    └── elder/
        ├── detection_result_dialog.dart
        ├── detection_history_dialog.dart
        ├── ocr_result_dialog.dart
        └── tts_section.dart
```

---

## 7. Patterns architecturaux

### 7.1 MVC côté backend

Le backend applique le pattern **MVC** (Model–View–Controller) :

- **Model** : schémas Mongoose (`/models`) — définissent la structure des données et les contraintes.
- **Controller** : classes dans `/controllers` — reçoivent la requête HTTP, valident les paramètres, délèguent au service, retournent la réponse JSON.
- **Service** : classes dans `/services` — contiennent la logique métier pure (calculs, accès base de données, appels externes), indépendantes du protocole HTTP.
- **View** : JSON (API REST), pas de rendu HTML côté serveur.

**Exemple de flux :**
```
POST /elder/signup-face
  → elderRoutes.js (routing)
  → elderController.signupFace() (validation params)
  → elderService.signupFace() (logique cosine similarity + persistance)
  → Elder.create() (Mongoose)
  → Response JSON
```

### 7.2 Layered Architecture côté Flutter

Flutter suit une architecture en couches :

```
Screens (UI)         → affichage, interaction utilisateur
    ↓
Services             → logique métier, appels réseau, gestion état partagé
    ↓
Models               → structures de données (DTOs)
    ↓
Utils                → fonctions pures, helpers, storage
```

### 7.3 Repository Pattern (implicite)

`ApiService` joue le rôle de **Repository** : il centralise l'accès à la source de données distante (backend REST). Tous les écrans passent par ce singleton pour effectuer leurs appels réseau, découplant ainsi la couche présentation des détails d'implémentation HTTP.

### 7.4 Event-Driven Architecture (WebSocket)

Le temps réel repose sur une **architecture orientée événements** via Socket.IO :

- Le backend émet des événements (`elderPresence`, `caregiverPresence`, `objectDetectionResult`, `pairStatus`).
- Les clients Flutter s'abonnent aux événements via `PresenceService.presenceStream`.
- Le service IA (`aiService`) traite l'image en arrière-plan et émet le résultat via Socket.IO dans la room `elder:{elderId}` sans bloquer la réponse HTTP initiale.

---

## 8. Design Patterns utilisés

### 8.1 Singleton

Utilisé pour les services partagés nécessitant une instance unique tout au long du cycle de vie de l'application.

**Côté Flutter :**
- `ApiService` — instance unique via factory constructor `_instance`
- `PresenceService` — instance unique, gère le socket Socket.IO
- `InMemoryFaceStorage` — instance unique, gère la session utilisateur
- `LocationService` — instance unique, stream GPS
- `SOSService` — instance unique

**Côté backend :**
- `new AIService()` / `new ElderService()` / `new CaregiverService()` — instanciés une fois dans leur fichier, exportés comme singletons.

```dart
// Exemple Flutter
class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();
}
```

### 8.2 Observer / Stream

`PresenceService` expose un `StreamController.broadcast()`. Les widgets s'y abonnent via `listen()` pour réagir aux changements de présence ou aux résultats IA.

```dart
_presenceSubscription = _presenceService.presenceStream.listen((data) {
  setState(() { _elderOnline = data['online']; });
});
```

### 8.3 Strategy (IA d'identification)

Le module d'identification d'objets dans `AccessibilityScreen` implémente une stratégie en cascade :

1. **Stratégie principale** : envoi de l'image à Ollama (backend) → résultat asynchrone via WebSocket.
2. **Stratégie de fallback** : si Ollama est indisponible, basculement sur TFLite on-device (MobileNet + ML Kit).

```dart
final sent = await _sendImageToBackend(file, elderId);  // Stratégie 1
if (!sent) {
  final rawResults = await _detectWithTFLite(file);     // Stratégie 2 (fallback)
}
```

### 8.4 Factory Method

`Medication.fromJson()` est une factory method qui produit une instance `Medication` à partir d'un Map JSON, encapsulant les règles de mapping et de gestion des valeurs nulles.

### 8.5 Template Method

La structure des routes Express suit un template implicite : chaque contrôleur applique le même schéma — validation des params → appel service → gestion erreur → réponse JSON — grâce à la convention try/catch systématique.

### 8.6 Decorator (Middleware)

Le middleware `asyncHandler` est un **decorator** fonctionnel : il enveloppe n'importe quelle fonction de route async pour capturer les rejets de promesses et les propager à Express sans répéter le try/catch.

```javascript
const asyncHandler = (fn) => (req, res, next) =>
  Promise.resolve(fn(req, res, next)).catch(next);
```

### 8.7 Command (Notifications natives)

Les commandes envoyées au canal natif Android (`fall_channel`) encapsulent des actions spécifiques (`scheduleMedication`, `cancelMedication`, `scheduleTask`, `cancelTask`, `sendSMS`, `startService`) suivant le pattern Command via le `MethodChannel` Flutter.

### 8.8 Facade

`HomeService` est une **façade** qui simplifie l'orchestration de plusieurs services complexes (médicaments, tâches, téléphone aidant) en un seul appel `_setupApp()` depuis `HomeScreen`.

---

## 9. Modules fonctionnels

### 9.1 Authentification faciale

**Processus d'inscription :**
1. Capture vidéo en continu via `CameraController`.
2. Détection des visages avec Google ML Kit `FaceDetector`.
3. Vérification du centrage dans le cadre circulaire.
4. Capture d'un buffer d'embeddings sur 3 secondes.
5. Calcul de l'embedding moyen (moyenne vectorielle).
6. Normalisation L2 de l'embedding.
7. Comparaison cosine similarity avec tous les embeddings existants (seuil 0.50).
8. Si nouveau → création Elder + code de liaison unique à 6 chiffres.
9. Si existant → retour de l'ID Elder existant.

**Modèle :** MobileFaceNet (TFLite, 112×112 pixels, embedding 192 dimensions).

### 9.2 SOS et alertes

**Cascade d'envoi :**
1. Appel API `POST /alerts/create` (enregistrement en base + notification aidant).
2. Email SMTP via Gmail (mailer package).
3. Si pas d'Internet : SMS natif Android via `fall_channel.sendSMS`.

**Détection automatique de chutes :**
- Service Android natif en foreground (FlutterForegroundTask).
- Analyse de l'accéléromètre côté Android natif.
- En cas de chute détectée : événement sur `fall_events` EventChannel → `_onFallEvent()` → `SOSService.sendSOS()`.

### 9.3 Gestion des médicaments

**Côté aidant :** CRUD complet (nom, dosage, fréquence, jours, heures, photo, date début/fin).

**Côté senior :**
- Filtrage des médicaments du jour selon fréquence et jours.
- Croisement avec l'historique des prises du jour.
- Confirmation de prise avec note textuelle ou enregistrement audio.
- L'audio est uploadé sur Cloudinary (resource_type: auto).
- L'aidant peut réécouter les confirmations vocales depuis l'historique.

**Notifications :** planifiées 15 minutes avant chaque prise via `MethodChannel.scheduleMedication`.

### 9.4 Identification IA d'objets

**Flux complet :**
```
Utilisateur prend une photo
  ↓
POST /ai/analyze-image (base64)
  ↓ (immédiat)
Réponse HTTP { status: "processing" }
  ↓ (asynchrone, ~2-10s)
Backend → Ollama qwen3-vl:2b → texte (1-3 mots)
  ↓
Socket.IO emit("objectDetectionResult", { result, image }) → room elder:{id}
  ↓
Flutter PresenceService stream → SnackBar + Dialog + TTS "C'est [objet]"
```

**Fallback si Ollama indisponible :**
```
ML Kit Object Detector → bounding boxes
  ↓
TFLite Classifier sur chaque crop
  ↓
Traduction EN→FR (LabelTranslations)
  ↓
Résultat immédiat sans websocket
```

### 9.5 Présence et temps réel

**Rooms Socket.IO :**
- `elder:{elderId}` — rejointe à la connexion du senior et de l'aidant lié.
- `caregiver:{caregiverId}` — rejointe uniquement par l'aidant.

**Heartbeat :**
- Côté senior : `elderHeartbeat` toutes les 30s → mise à jour `lastActiveAt`.
- Côté aidant : `caregiverHeartbeat` toutes les 30s + HTTP polling de secours toutes les 30s.
- Statut "en ligne" = `lastActiveAt` < 60 secondes.

---

## 10. Flux de données

### 10.1 Flux SOS

```
Senior presse bouton SOS
→ HomeScreen._handleSOSPress()
→ SOSService.sendSOS(position)
→ [1] ApiService.createAlert() → POST /alerts/create
     → Alert.create() en base
→ [2] _sendEmailAlert() → SMTP Gmail
→ [3] Si offline : sendSMSFallback() → MethodChannel.sendSMS
```

### 10.2 Flux confirmation médicament

```
Senior tape "Prendre"
→ MedicationConfirmationDialog (note + audio optionnel)
→ ApiService.confirmMedicationTake()
→ POST /medications/confirm-take (multipart si audio)
→ Cloudinary upload audio (si présent)
→ MedicationLog.create() en base
→ MedicationReminderService.cancelMedication()
→ MethodChannel.cancelMedication
```

### 10.3 Flux reconnaissance faciale (signin)

```
Camera stream → CameraImage
→ FaceDetectorService.detectFaces()
→ Si visage centré : buffer 3 secondes d'embeddings
→ _averageEmbeddings() → vecteur moyen
→ ApiService.elderSigninFace(embedding)
→ POST /elder/signin-face
→ ElderService.signinFace()
   → cosineSimilarity() avec tous les embeddings en base
   → seuil ≥ 0.50 → matched: true
→ InMemoryFaceStorage.setElderId() + setLoggedIn(true)
→ Navigation → ElderlyNavigation
```

---

## 11. Workflows complexes — Détail complet

Cette section documente les workflows non triviaux du projet, avec chaque étape, chaque condition, chaque composant impliqué et les cas d'erreur associés.

---

### WF-01 — Inscription et Authentification Faciale du Senior

Ce workflow est le plus critique de l'application : il remplace le couple email/mot de passe par une reconnaissance biométrique embarquée.

```
┌─────────────────────────────────────────────────────────────────────────┐
│                     INSCRIPTION FACIALE (signup)                        │
└─────────────────────────────────────────────────────────────────────────┘

PHASE 1 — Initialisation caméra
────────────────────────────────
[FaceSignupScreen.initCamera()]
  ↓
availableCameras()                          → liste des caméras disponibles
  ↓
Sélection caméra frontale (lensDirection = front)
  ↓
CameraController(ResolutionPreset.high, yuv420)
  ↓
controller.initialize() + startImageStream(_processCameraImage)
  ↓
setState() → affichage CameraPreview + CustomPaint(FacePainter)

PHASE 2 — Détection en continu (frame par frame)
──────────────────────────────────────────────────
[_processCameraImage(CameraImage image)]  ← appelé ~30fps

  SI _isDetecting == true → return   (évite la surcharge)
  _isDetecting = true

  [1] Conversion CameraImage → InputImage
       WriteBuffer.putUint8List(plane.bytes pour chaque plan)
       InputImageMetadata(size, rotation=sensorOrientation, format=NV21/BGRA)

  [2] FaceDetectorService.detectFaces(inputImage)
       → Google ML Kit FaceDetector (mode: fast, landmarks: true, contours: true)
       → retourne List<Face>

  [3] Calcul imageSize (swap w/h si rotation 90° ou 270°)

  [4] setState({ _faces, _isCentered })
       _isCentered = _checkCentered(faces.first)
       Critère : distance normalisée du centre du visage < 0.20

  [5] SI visage détecté :
       convertCameraImageToImage(image)    → img.Image (luminance)
       rotateForSensor(imgImage, rotation) → correction orientation
       cropFace(rotated, faces.first)      → crop bbox avec clamp
       resizeFace(faceCrop, 112)           → 112×112 pixels
       img.flipHorizontal(faceCrop)        → miroir caméra frontale
       FaceRecognitionService.getEmbedding(faceCrop)
         → imageToByteList() : normalisation [-1, 1] par canal
         → TFLite MobileFaceNet.run([1,112,112,3] → [1,192])
         → List<double> embedding (192 dimensions)

  [6] SI _isCapturing :
       _embeddingBuffer.add(embedding)    → accumulation
      SINON SI _isCentered :
       _embeddingBuffer = [embedding]
       _startCapture()                    → timer 3 secondes

PHASE 3 — Capture et moyenne des embeddings
─────────────────────────────────────────────
[_startCapture()]
  _isCapturing = true
  _captureEndTime = now + 3s
  Timer(3s) → callback :

    SI _embeddingBuffer.length < 3 :
      → showErrorSnackBar("Pas assez d'échantillons")
      → _cancelCapture() → réinitialisation

    SINON :
      _averageEmbeddings(buffer)
        → Pour chaque dimension i : sum[i] / count
        → Retourne vecteur moyen [192 doubles]
      _lastEmbedding = averaged
      → _onRegister()

PHASE 4 — Enregistrement côté backend
───────────────────────────────────────
[_onRegister()]

  ApiService.elderSignupFace(embedding: _lastEmbedding, profile: {})
    → POST /elder/signup-face
      Body: { embedding: [192 floats], profile: {} }

  [Backend — ElderService.signupFace()]
    normalize(embedding)   → normalisation L2 : v[i] / ||v||
    
    Elder.find({}, { embeddings: 1, relationCode: 1 })
    → Pour chaque elder en base :
        Pour chaque vecteur existant :
          cosineSimilarity(embN, normalize(vec))
            = dot(a,b) / (||a|| × ||b||)
          SI similarité ≥ 0.50 :
            → return { elderId, code, created: false, message: "existing" }

    Aucune correspondance trouvée :
      generateUniqueCode() → code 6 chiffres aléatoire (vérif unicité en base)
      Elder.create({ profile, relationCode: code, embeddings: [embN] })
      → return { elderId, code, created: true, message: "new" }

PHASE 5 — Post-traitement Flutter
───────────────────────────────────
  SI created == true (nouveau compte) :
    InMemoryFaceStorage.saveEmbedding()   → SharedPreferences 'face_embedding'
    InMemoryFaceStorage.setElderId()      → SharedPreferences 'elder_id'
    InMemoryFaceStorage.setElderCode()    → SharedPreferences 'elder_code'
    setRole('personne_agee') + setLoggedIn(true)
    MethodChannel('fall_channel').invokeMethod('startService')
    → Navigation → ElderProfileCompletionScreen(elderId)
      → Formulaire prénom/nom/genre/âge
      → POST /elder/update-profile
      → Navigation → ElderlyNavigation

  SI created == false (visage déjà enregistré) :
    → Navigation → ElderlyNavigation (reconnexion silencieuse)

GESTION D'ERREURS
──────────────────
  • Erreur réseau                → showErrorSnackBar + _cancelCapture()
  • < 3 embeddings capturés     → showErrorSnackBar + _cancelCapture()
  • Caméra non initialisée      → CircularProgressIndicator (loading state)
  • Face perdue pendant capture → _cancelCapture() automatique
```

---

### WF-02 — Connexion Faciale du Senior

Identique au signup côté capture, mais la logique de décision est inversée (recherche au lieu de création).

```
┌─────────────────────────────────────────────────────────────────────────┐
│                      CONNEXION FACIALE (signin)                         │
└─────────────────────────────────────────────────────────────────────────┘

Phases 1, 2, 3 : identiques au signup (caméra, détection, buffer 3s)

PHASE 4 — Authentification côté backend
─────────────────────────────────────────
[_startCapture() → callback après 3s]

  _averageEmbeddings(buffer) → vecteur moyen

  ApiService.elderSigninFace(embedding: averaged)
    → POST /elder/signin-face

  [Backend — ElderService.signinFace()]
    normalize(embedding) → normalisation L2
    Elder.find({}, { embeddings: 1, relationCode: 1 })
    best = { score: 0, elder: null }

    Pour chaque elder, pour chaque embedding stocké :
      score = cosineSimilarity(embN, normalize(vec))
      SI score > best.score → best = { score, elder }

    SI best.elder != null ET best.score ≥ 0.50 :
      → return { elderId, code, matched: true, message: "recognized" }
    SINON :
      → return { elderId: "", code: "", matched: false, message: "no_match" }

PHASE 5 — Post-traitement
───────────────────────────
  SI elderId non vide (matched) :
    setState({ _authStatus: "Authentification réussie !", _statusColor: green })
    ctrl.stopImageStream() + ctrl.dispose()
    InMemoryFaceStorage.setLoggedIn(true)
    InMemoryFaceStorage.setRole('personne_agee')
    InMemoryFaceStorage.setElderId(elderId)
    InMemoryFaceStorage.setElderCode(elderCode)
    MethodChannel.startService()
    → Navigation → ElderlyNavigation

  SINON :
    setState({ _authStatus: "Visage non reconnu", _statusColor: red })
    showSnackBar("Aucun utilisateur correspondant")
    _isCapturing = false
    _readyToCapture = false  ← force recentrage avant nouvelle tentative
```

---

### WF-03 — Inscription de l'Aidant et Liaison avec un Senior

```
┌─────────────────────────────────────────────────────────────────────────┐
│                   INSCRIPTION AIDANT + LIAISON SENIOR                   │
└─────────────────────────────────────────────────────────────────────────┘

ÉTAPE 1 — Formulaire
──────────────────────
CaregiverSignupScreen collecte :
  prénom, nom, email, mot de passe (min 6 car.), téléphone, genre
  + code de liaison senior (optionnel, 6 chiffres)

ÉTAPE 2 — Vérification du code senior (optionnelle mais obligatoire si saisi)
───────────────────────────────────────────────────────────────────────────
[_verifyCode()]
  ApiService.verifyElderCode(code)
    → GET /elder/verify-code/:code
    → Elder.findOne({ relationCode: code })
    SI trouvé : return { valid: true, elder: { firstName, lastName } }
    SINON     : return { valid: false }

  SI valid == true :
    _isCodeVerified = true
    showSnackBar("Code valide ! Senior: Prénom Nom")
  SINON :
    _isCodeVerified = false
    showSnackBar("Code invalide")

  ⚠️ Si le code a été saisi mais pas vérifié → _signup() bloqué

ÉTAPE 3 — Création du compte
──────────────────────────────
[_signup()]
  Validation formulaire (FormKey)
  SI _selectedGender == null → erreur
  SI code saisi ET !_isCodeVerified → erreur

  ApiService.caregiverSignup(email, password, phone, gender, firstName, lastName, elderCode)
    → POST /caregiver/signup
    Body: { email, password, phone, gender, firstName, lastName, elderCode }

  [Backend — CaregiverService.signup()]
    Caregiver.findOne({ email }) → SI existant : throw 409 "email déjà utilisé"
    bcrypt.hash(password, 10) → passwordHash
    linkedElderId = null
    SI elderCode fourni :
      Elder.findOne({ relationCode: elderCode })
      SI trouvé : linkedElderId = elder._id
    Caregiver.create({ email, passwordHash, phone, gender, firstName, lastName, linkedElderId })
    → return { caregiverId, linkedElderId }

ÉTAPE 4 — Session locale
──────────────────────────
  InMemoryFaceStorage.setRole('aidant')
  InMemoryFaceStorage.setLoggedIn(true)
  InMemoryFaceStorage.setCaregiverId(resp.caregiverId)
  SI resp.linkedElderId != null :
    InMemoryFaceStorage.setElderId(resp.linkedElderId)
  → Navigation → CaregiverNavigation

GESTION D'ERREURS
──────────────────
  • Email déjà utilisé (409)  → message d'erreur
  • Erreur réseau             → showSnackBar "Erreur lors de l'inscription"
  • Code non vérifié          → bloqué avant envoi
```

---

### WF-04 — Pipeline SOS Complet (Bouton + Détection de Chute)

Ce workflow est le plus critique en termes de fiabilité. Il implémente une cascade de 3 niveaux de notification.

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    DÉCLENCHEMENT SOS — CASCADE COMPLÈTE                 │
└─────────────────────────────────────────────────────────────────────────┘

SOURCE A — Bouton SOS manuel
─────────────────────────────
[HomeScreen]
  GestureDetector.onTapDown → _handleSOSPress()
    setState({ _sosPressed: true })
    Timer(2s) → SI _sosPressed encore : sendSOS()

  GestureDetector.onTapUp → _handleSOSRelease()
    showSnackBar("SOS Envoyé")
    Timer.cancel()
    setState({ _sosPressed: false })

SOURCE B — Détection automatique de chute
───────────────────────────────────────────
[Android natif — FallDetectionService]
  AccelerometerListener → analyse vecteur accélération
  SI magnitude > seuil ET suivi d'inactivité :
    → EventChannel('fall_events').send("FALL_DETECTED")

[Flutter — HomeScreen._initFallDetection()]
  fallEventsChannel.receiveBroadcastStream().listen(_onFallEvent)
  _onFallEvent() → SOSService.sendSOS(lastKnownPosition)

PIPELINE SOSService.sendSOS(position)
──────────────────────────────────────
  elderId = InMemoryFaceStorage().getElderId()
  SI elderId == null → return (pas de session)

  lat = position?.latitude
  lng = position?.longitude

  [Vérification connectivité]
  hasInternet() → InternetAddress.lookup('google.com')
  SI pas d'Internet :
    sendSMSFallback(lat, lng)   ← SMS natif sans réseau data
    (puis continue quand même pour les autres canaux si réseau revient)

  NIVEAU 1 — API Backend
  ─────────────────────
  ApiService.createAlert(
    elderId, type: 'SOS_BUTTON',
    description: 'Bouton SOS pressé...',
    latitude, longitude
  )
  → POST /alerts/create
  [Backend]
    Elder.findById(elderId)
    Caregiver.findOne({ linkedElderId: elder._id })
    SI caregiver non trouvé → 404
    Alert.create({
      elderId, caregiverId,
      type: "SOS_BUTTON" | "generic" | "sos",
      message, latitude, longitude, read: false
    })
    → { ok: true, alertId }

  NIVEAU 2 — Email SMTP
  ─────────────────────
  _sendEmailAlert(lat, lng)
    smtpUser, smtpPassword, smtpRecipient ← dotenv
    SI config incomplète → log + return
    smtpServer = gmail(smtpUser, smtpPassword)
    googleMapsUrl = "https://maps.google.com/?q=lat,lng"
    Message:
      from: smtpUser (CareLink Alert)
      to: smtpRecipient
      subject: 'ALERTE SOS - CareLink'
      body: 'Alerte SOS déclenchée. Position: [URL Google Maps]'
    send(message, smtpServer)

  NIVEAU 3 — SMS natif (fallback offline)
  ────────────────────────────────────────
  sendSMSFallback(lat, lng)
    recipient = InMemoryFaceStorage().getCaregiverPhone() ?? SMS_TO (env)
    SI recipient vide → log + return
    Permission.sms.request()
    SI accordée :
      message = "ALERTE SOS - CareLink\nPosition: maps.google.com?q=lat,lng\nLat: X, Lon: Y"
      MethodChannel('fall_channel').invokeMethod('sendSMS', { phone, message })
      → Android natif : SmsManager.sendTextMessage()

GESTION D'ERREURS MULTI-NIVEAUX
──────────────────────────────────
  Chaque niveau est dans try/catch indépendant
  Échec niveau 1 → log + continue niveau 2
  Échec niveau 2 → log + continue niveau 3
  Échec niveau 3 → log uniquement
  → Pas de blocage : au moins un canal doit fonctionner
```

---

### WF-05 — Identification d'Objets par IA (Pipeline Hybride)

Workflow à deux stratégies avec basculement automatique selon la disponibilité d'Ollama.

```
┌─────────────────────────────────────────────────────────────────────────┐
│              IDENTIFICATION D'OBJETS — PIPELINE HYBRIDE IA              │
└─────────────────────────────────────────────────────────────────────────┘

PRÉREQUIS
──────────
[AccessibilityScreen.initState()]
  MLService.initialize()
    _initMLKit() → ObjectDetector(single, classifyObjects, multipleObjects)
    _loadClassifier()
      Interpreter.fromAsset('assets/classifier.tflite', threads: 4)
      rootBundle.loadString('assets/labels.txt') → List<String> labels
      Log: input shape, output tensors count

[PresenceService.initSocket('senior')]
  → Connexion WebSocket + inscription room elder:{elderId}
  → Écoute événement 'objectDetectionResult'

DÉCLENCHEMENT
──────────────
[_handleObjectLabeling()]
  SI !_mlService.isModelLoaded → showSnackBar "IA en chargement"
  
  XFile file = await _picker.pickImage(
    source: ImageSource.camera,
    preferredCameraDevice: CameraDevice.rear,
    imageQuality: 92
  )
  SI file == null → return (annulé par l'utilisateur)
  
  setState({ _isObjectScanning: true, _lastImagePath: file.path })
  elderId = InMemoryFaceStorage().getElderId()

STRATÉGIE 1 — Ollama via Backend (préféré)
────────────────────────────────────────────
[_sendImageToBackend(file, elderId)]
  bytes = await file.readAsBytes()
  base64Image = base64Encode(bytes)
  
  ApiService.analyzeImage(base64Image, elderId)
    → POST /ai/analyze-image
      Body: { image: base64, elderId }

  [Backend — AIController.analyzeImage()]
    SI !image → 400
    axios.get("http://localhost:11434/api/tags") → vérif Ollama disponible
    SI Ollama KO → throw 500

    this.processImageInBackground(image, elderId)  ← NON BLOQUANT
    return { status: "processing", message: "L'analyse a commencé." }  ← IMMÉDIAT

  [Backend — processImageInBackground() - async, séparé]
    axios.post(OLLAMA_URL, {
      model: "qwen3-vl:2b-instruct-q4_K_M",
      messages: [{
        role: "user",
        content: "Identify the main visible object... 1 to 3 words max...",
        images: [base64Image]
      }],
      stream: false
    })
    → aiResponse = response.data.message.content.trim()
    
    io = socketService.getIO()
    io.to(`elder:${elderId}`).emit("objectDetectionResult", {
      result: aiResponse,    ← ex: "water bottle"
      image: base64Image
    })

  [Flutter — PresenceService._socket.on('objectDetectionResult')]
    _presenceController.add({ type: 'objectDetectionResult', data })

  [AccessibilityScreen._listenToPresenceEvents()]
    SI event.type == 'objectDetectionResult' :
      _handleDetectionResultEvent(event['data'])
        aiResult = data['result']          ← "water bottle"
        imageBase64 = data['image']
        resultText = "C'est $aiResult."
        _saveToHistory(label, labelFr, imageBase64)  → SharedPreferences (max 20)
        _showResultToast(resultText, aiResult, imageBase64)
          → SnackBar 8s + action "VOIR"
          → _flutterTts.speak(resultText)   ← lecture vocale immédiate
          → SI "VOIR" cliqué : _showDetectionResult() → Dialog

  Flutter reçoit HTTP 200 :
    setState({ _isObjectScanning: false })
    showSnackBar("Analyse d'image en cours...")
    return true ← STRATÉGIE 1 RÉUSSIE

STRATÉGIE 2 — TFLite On-Device (fallback)
───────────────────────────────────────────
[Si Stratégie 1 lève une exception]
  → sent = false

[_detectWithTFLite(file)]
  mlObjects = await _mlService.detectObjects(file.path)
    → ML Kit ObjectDetector.processImage(InputImage.fromFilePath)
    → List<DetectedObject> avec boundingBox et labels

  bytes = await File(file.path).readAsBytes()
  fullImg = img.decodeImage(bytes)

  SI mlObjects.isEmpty OU fullImg == null :
    → _classifyFullImage(fullImg)
       mlService.classifyImage(fullImg ?? Image(300,300))
         → Resize → width x height selon input tensor
         → Normalisation uint8 [0,255] ou float32 [0.0,1.0]
         → interpreter.runForMultipleInputs([input], outputs)
         → Extraction scores + classes depuis output tensors
         → Filtre confiance < 0.25
         → return { label, confidence }

  SINON :
    _classifyDetectedObjects(mlObjects, fullImg)
      Pour chaque objet détecté :
        bbox = obj.boundingBox
        croppedImg = cropWithMargin(fullImg, bbox)
          margin = (w + h) * 0.05   ← marge de 5%
          img.copyCrop(source, left, top, w, h)
        tfliteResult = mlService.classifyImage(croppedImg)
        SI résultat : results.add({...tfliteResult, box: bbox, source: "tflite"})
        SINON SI obj.labels non vide :
          results.add({ label, confidence, box, source: "mlkit" })

POST-TRAITEMENT FALLBACK
──────────────────────────
  withFr = translateAndDeduplicate(rawResults)
    Pour chaque résultat :
      fr = LabelTranslations.translate(r["label"])
        → Lookup exact dans Map<String,String> (250+ entrées)
        → SI pas trouvé : lookup partiel (contains)
        → SI toujours pas : retour label anglais
      SI fr pas encore dans seen : ajout (déduplication)

  labels = withFr.map((r) => r['labelFr']).toList()
  resultText = buildResultSentence(labels)
    SI 0 labels : "Je n'arrive pas à identifier d'objets ici."
    SI 1 label  : "C'est $label."
    SI n labels : "Je vois : $l1, $l2, $l3."

  _flutterTts.speak(resultText)
  _showTFLiteDetectionResult(filePath, mlObjects, withFr, resultText)
    → Dialog avec image + bounding boxes CustomPaint + confiance %

RENDU VISUEL — DetectionResultDialog
──────────────────────────────────────
  Image (base64 ou File) dans Container 320px height
  CustomPaint(DetectionPainter)
    Pour chaque résultat avec "box" :
      Calcul scale + offset pour fit de l'image dans le widget
      drawRect (vert/teal/orange selon source et confiance)
      TextPainter(label + %, backgroundColor: black54)
  Liste résultats avec : icône source, label FR, badge confiance coloré
    Vert ≥ 70% / Orange 45-70% / Rouge < 45%
  Boutons : RÉÉCOUTER (TTS) + MERCI (dismiss)
```

---

### WF-06 — Rappels et Confirmation de Médicaments

Ce workflow couvre l'ensemble du cycle de vie d'un médicament, de la planification par l'aidant jusqu'à la confirmation vocale par le senior.

```
┌─────────────────────────────────────────────────────────────────────────┐
│              CYCLE DE VIE COMPLET D'UN MÉDICAMENT                       │
└─────────────────────────────────────────────────────────────────────────┘

PHASE 1 — Création par l'Aidant
────────────────────────────────
[CaregiverMedicationsScreen → AddMedicationScreen]

  Formulaire :
    - nom, dosage (requis)
    - fréquence : Quotidien | Hebdomadaire | Mensuel | Au besoin
    - SI Hebdomadaire : sélection jours (L=1 à D=7)
    - horaires : List<TimeOfDay> (min 1, ajout dynamique)
    - date début (requis), date fin (optionnel)
    - instructions libres
    - photo (optionnel) → ImagePicker (caméra ou galerie)
    - statut actif/inactif (Switch)

  [_submit()]
    timesStrings = times.map("HH:mm")
    ApiService.addMedication(medicationData, image: File?)
      → MultipartRequest POST /medications
        Fields: name, dosage, frequency, days(JSON), times(JSON),
                startDate, endDate, instructions, elderId, caregiverId, active
        File: photo (si présente)

    [Backend — POST /medications]
      Multer.single('photo') → req.file.buffer (memoryStorage)
      SI req.file :
        uploadToCloudinary(buffer, 'medications', 'image')
          → streamifier.createReadStream(buffer).pipe(cloudinary.upload_stream)
          → return secure_url
      Medication.create({ ...fields, photoUrl })
      → 201 { medication }

PHASE 2 — Planification des notifications
───────────────────────────────────────────
[HomeService.scheduleMedications() — appelé au démarrage de HomeScreen]

  ApiService.getMedications(elderId)
  ApiService.getElderMedicationHistoryToday(elderId)
    → GET /medications/history/elder/:elderId/today
    → MedicationLog.find({ elderId, takenAt: [startOfDay, endOfDay] })
  takenTodayIds = Set des IDs médicaments déjà pris aujourd'hui

  Filtrage des médicaments du jour :
    med.active == true
    AND startDate <= aujourd'hui
    AND (endDate == null OR endDate >= aujourd'hui)
    AND SI Hebdomadaire : med.days.contains(now.weekday)

  untakenMeds = todayMeds où id NOT IN takenTodayIds

  MedicationReminderService.scheduleForMedications(untakenMeds)
    Pour chaque médicament, pour chaque horaire[i] :
      Calcul nextTime selon fréquence :
        Quotidien  : aujourd'hui à HH:mm (ou demain si passé)
        Hebdomadaire : prochain jour correspondant dans 14 jours max

      finalTime = nextTime - 15 minutes
      SI finalTime passé :
        SI nextTime futur : finalTime = nextTime, label = "Maintenant"
        SINON : skip

      alarmId = "${med.id}_$i"
      MethodChannel('fall_channel').invokeMethod('scheduleMedication', {
        id: alarmId, name: label, dosage, timestamp: finalTime.ms
      })
      → Android : AlarmManager.setExactAndAllowWhileIdle()
      → Notification locale à finalTime

  Pour chaque med déjà pris :
    MedicationReminderService.cancelMedicationById(medId, timesCount)
      MethodChannel.cancelMedication({ id: "${medId}_$i" })
      → Android : AlarmManager.cancel()

PHASE 3 — Affichage et filtrage côté Senior
─────────────────────────────────────────────
[MedicationsScreen._fetchMedications()]

  Récupération + croisement avec historique du jour
  Tri par premier horaire de la journée
  Affichage :
    - Carte "Prochain médicament" → horaire + nom + dosage
    - Liste du jour : chaque médicament avec bouton "Prendre"
    - Médicament pris : opacité 0.6 + icône check verte + texte barré

  _getNextMedication() :
    SI tous pris → null → carte "Bravo ! Tous pris."
    SINON → premier médicament non pris dont prochain horaire > maintenant

PHASE 4 — Confirmation de prise
─────────────────────────────────
[Senior tape "Prendre" → _showConfirmationDialog(med)]

  MedicationConfirmationDialog :
    TextField (note texte, optionnel)
    Bouton micro :
      onPressed → AudioRecorder.hasPermission()
      SI accordée :
        dir = getTemporaryDirectory()
        path = "${dir}/med_audio_${timestamp}.m4a"
        AudioRecorder.start(RecordConfig(), path)
        setState({ _isRecording: true })
      onPressed (arrêt) :
        AudioRecorder.stop()
        setState({ _isRecording: false })
    
    Bouton CONFIRMER :
      Navigator.pop()
      _confirmTake(med, note, audioPath)

  [_confirmTake()]
    setState({ _isLoading: true })
    elderId = InMemoryFaceStorage().getElderId()

    ApiService.confirmMedicationTake(
      medicationId: med.id, elderId, note, audioFile: File(audioPath), status: 'taken'
    )
    → MultipartRequest POST /medications/confirm-take
      Fields: medicationId, elderId, status, note
      File: audio (si présent)

    [Backend — POST /medications/confirm-take]
      Caregiver.findOne({ linkedElderId: elderId }) → caregiverId
      SI audio :
        uploadToCloudinary(buffer, 'medication-audio', 'auto')  ← resource_type: auto pour audio
        → audioUrl Cloudinary
      MedicationLog.create({ medicationId, elderId, caregiverId, status, note, audioUrl, takenAt })
      → 201 { log }

    Flutter reçoit 201 :
      SI note non vide : _flutterTts.speak(note)  ← lecture vocale de la note
      setState({ _takenMedications.add(med.id) })
      MedicationReminderService.cancelMedication(med)  ← annulation alarmes
      showSnackBar("Prise confirmée !")

PHASE 5 — Consultation par l'Aidant
──────────────────────────────────────
[CaregiverMedicationHistoryScreen]

  ApiService.getMedicationHistory(caregiverId)
    → GET /medications/history/:caregiverId
    → MedicationLog.find({ caregiverId })
         .populate('medicationId', 'name dosage')
         .sort({ takenAt: -1 })

  Affichage par log :
    nom médicament + dosage
    badge statut (pris/skipped/missed)
    date/heure de prise

    SI audioUrl présent :
      Bouton "Écouter le message vocal"
      _playAudio(url) :
        SI même URL en cours → AudioPlayer.stop()
        SINON :
          _audioPlayer.stop() + _flutterTts.stop()  ← arrêt toute lecture
          AudioPlayer.play(UrlSource(formattedUrl))
          onPlayerComplete → _currentlyPlayingUrl = null

    SI note texte (sans audio) :
      Bouton "Écouter la note (vocal)"
      _flutterTts.speak(note)
```

---

### WF-07 — Présence en Temps Réel (WebSocket Bidirectionnel)

```
┌─────────────────────────────────────────────────────────────────────────┐
│             PRÉSENCE TEMPS RÉEL — WEBSOCKET BIDIRECTIONNEL              │
└─────────────────────────────────────────────────────────────────────────┘

CONNEXION — Côté Senior
────────────────────────
[ElderlyNavigation.initState()]
  PresenceService.initSocket('senior')
    id = InMemoryFaceStorage().getElderId()
    SI socket déjà connecté avec même rôle+id → return (idempotent)
    SI socket existant (rôle différent) → disconnect + dispose

    io.Socket = io.io(baseUrl, OptionBuilder().setTransports(['websocket']))
    socket.onConnect → emit('registerElder', { elderId: id })

    [Backend — socketService.on('registerElder')]
      socket.data.elderId = elderId
      socket.join(`elder:${elderId}`)
      Elder.findByIdAndUpdate(elderId, { lastActiveAt: now })
      Caregiver.find({ linkedElderId: elderId })
      Pour chaque caregiver lié :
        io.to(`caregiver:${cg._id}`).emit('elderPresence', {
          online: true, lastActiveAt: now, elderId
        })
        SI caregiver online (lastActiveAt < 60s) :
          io.to(`caregiver:${cg._id}`).emit('pairStatus', {
            caregiverId, elderId, caregiverOnline: true, elderOnline: true
          })

    socket.on('objectDetectionResult', data)
      → _presenceController.add({ type: 'objectDetectionResult', data })

    _startHeartbeat('senior', id)
      Timer(30s) → socket.emit('elderHeartbeat', { elderId })

        [Backend — on('elderHeartbeat')]
          Elder.findByIdAndUpdate(elderId, { lastActiveAt: now })
          Caregiver.find({ linkedElderId: elderId })
          Pour chaque caregiver :
            io.to(`caregiver:${cg._id}`).emit('elderPresence', {
              online: true, lastActiveAt: now, elderId
            })

CONNEXION — Côté Aidant
────────────────────────
[CaregiverHomeScreen.initState()]
  PresenceService.initSocket('aidant')
    emit('registerCaregiver', { caregiverId })

    [Backend — on('registerCaregiver')]
      socket.data.caregiverId = caregiverId
      Caregiver.findByIdAndUpdate(caregiverId, { lastActiveAt: now })
      SI cg.linkedElderId :
        elderRoom = `elder:${cg.linkedElderId}`
        caregiverRoom = `caregiver:${cg._id}`
        socket.join(elderRoom)    ← aidant reçoit les événements elder
        socket.join(caregiverRoom)
        io.to(elderRoom).emit('caregiverPresence', {
          online: true, lastActiveAt: now, caregiverId
        })
        Elder.findById(cg.linkedElderId)
        elderOnline = (now - elder.lastActiveAt < 60000)
        io.to(caregiverRoom).emit('elderPresence', {
          online: elderOnline, lastActiveAt: elder.lastActiveAt, elderId
        })

    socket.on('elderPresence', data)
      → _presenceController.add(data)

  presenceStream.listen(data)
    setState({
      _elderOnline = data['online']
      _elderLastActiveAt = data['lastActiveAt']
    })

  Timer(30s) → PresenceService.refreshPresenceViaHttp(caregiverId)
    ApiService.caregiverHeartbeat(caregiverId)
      → POST /caregiver/:id/heartbeat
      [Backend]
        Caregiver.findByIdAndUpdate(id, { lastActiveAt: now })
        Elder.findById(cg.linkedElderId)
        elderOnline = (diff < 60000)
        return { caregiverId, online, lastActiveAt, elder: { elderId, online, lastActiveAt } }
    _presenceController.add(elder)  ← mise à jour via HTTP si socket défaillant

DÉCONNEXION
────────────
[Backend — on('disconnect')]
  elderId = socket.data.elderId
  SI elderId :
    room = `elder:${elderId}`
    sockets = io.sockets.adapter.rooms.get(room)
    SI room vide (plus aucun socket) :
      Elder.findByIdAndUpdate(elderId, { lastActiveAt: now })
      Pour chaque caregiver lié :
        emit('elderPresence', { online: false, lastActiveAt: now })

CALCUL DU STATUT "EN LIGNE"
────────────────────────────
  online = (now - lastActiveAt) < 60_000ms  ← fenêtre 60 secondes
  SI heartbeat toutes 30s ET online < 60s → toujours "en ligne"
  SI app fermée brutalement → lastActiveAt non mis à jour → offline après 60s
```

---

### WF-08 — Détection de Chute (Service Android Natif + Flutter)

```
┌─────────────────────────────────────────────────────────────────────────┐
│              DÉTECTION DE CHUTE — SERVICE ANDROID + FLUTTER             │
└─────────────────────────────────────────────────────────────────────────┘

INITIALISATION DU SERVICE
───────────────────────────
[HomeScreen._initFallDetection()]

  MethodChannel('fall_channel').invokeMethod('startService')
    [Android natif]
      Lance ForegroundService avec notification persistante
      "Surveillance active — CareLink veille sur vous"
      AccelerometerListener démarré
      AlarmManager initialisé

  fallEventsChannel.receiveBroadcastStream()
    .listen(_onFallEvent, onError: ...)
    → Écoute événements depuis Android natif

DÉTECTION (Android natif)
───────────────────────────
  SensorManager.SENSOR_ACCELEROMETER → onSensorChanged(SensorEvent)
  
  magnitude = sqrt(ax² + ay² + az²)
  
  SI magnitude > FALL_THRESHOLD (configurable, ~25 m/s²) :
    → Potentielle chute : démarrage temporisateur d'inactivité

  SI inactivité post-chute confirmée :
    EventChannel('fall_events').sink.add("FALL_DETECTED")

[Flutter — _onFallEvent(dynamic event)]
  SI event == "FALL_DETECTED" :
    SOSService.sendSOS(_locationService.lastKnownPosition)
    → Pipeline SOS complet (voir WF-04)

GESTION DES RÔLES
──────────────────
  Le service adapte son comportement selon le rôle :

  SI role == 'personne_agee' :
    AccelerometerListener ACTIF
    Service foreground avec notification SOS

  SI role == 'aidant' :
    AccelerometerListener INACTIF
    Service en mode allégé (pas de détection de chute)

  → MethodChannel.startService() est appelé à chaque changement de rôle
    (connexion aidant, connexion senior, déconnexion)

PLANIFICATION DES ALARMES MÉDICAMENTS/TÂCHES
──────────────────────────────────────────────
  Le même MethodChannel gère aussi :

  'scheduleMedication' → AlarmManager.setExactAndAllowWhileIdle(timestamp)
    → Notification: "Nom médicament (dans 15 min)"

  'cancelMedication'   → AlarmManager.cancel(alarmId)

  'scheduleTask'       → AlarmManager.setExactAndAllowWhileIdle(timestamp)
    → Notification: "Titre tâche (dans 15 min)"

  'cancelTask'         → AlarmManager.cancel(taskId)

  'sendSMS'            → SmsManager.sendTextMessage(phone, null, message, null, null)
```

---

### WF-09 — OCR et Lecture de Documents

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    OCR DOCUMENT + ENRICHISSEMENT + TTS                  │
└─────────────────────────────────────────────────────────────────────────┘

[AccessibilityScreen._handleOCR()]

ÉTAPE 1 — Capture photo
────────────────────────
  _picker.pickImage(source: ImageSource.camera)
  SI null → return

  setState({ _isOcrScanning: true })

ÉTAPE 2 — Reconnaissance de texte
───────────────────────────────────
  MLService.recognizeText(image.path)
    → TextRecognizer(script: TextRecognitionScript.latin)
    → InputImage.fromFilePath(imagePath)
    → textRecognizer.processImage(inputImage)
    → recognized.text.trim()   ← texte brut extrait

ÉTAPE 3 — Enrichissement contextuel
─────────────────────────────────────
  enrichOcrText(rawText)
    SI vide : "Aucun texte détecté. Réessayez avec une image plus nette."
    SI contient 'ordonnance' | 'dosage' | 'fois par jour' :
      return "📜 Ce document ressemble à une ordonnance.\n\n" + rawText
    SINON : rawText

ÉTAPE 4 — Affichage + Actions
───────────────────────────────
  setState({ _isOcrScanning: false })

  OCRResultDialog(text: enrichedText, fontSize: _fontSize)
    TextField scrollable avec le texte
    Bouton "LIRE À VOIX HAUTE" → _flutterTts.speak(enrichedText)
    Bouton "COPIER" → Clipboard.setData() + showSnackBar
    Bouton "FERMER" → _flutterTts.stop() + Navigator.pop()
```

---

### WF-10 — Gestion des Tâches Quotidiennes

```
┌─────────────────────────────────────────────────────────────────────────┐
│              TÂCHES QUOTIDIENNES — AJOUT, RAPPEL ET COMPLETION          │
└─────────────────────────────────────────────────────────────────────────┘

CRÉATION (Aidant ou Senior)
─────────────────────────────
[CaregiverTasksScreen._addTask() / DailyTasksScreen._addTask()]

  ModalBottomSheet :
    TextField titre (requis)
    TextField description (optionnel)
    ModernTimePicker : colonnes heures (0-23) + minutes (0-59) avec +/-
      → pas de showTimePicker natif (remplacé par sélecteur custom)

  [Aidant] elderId = widget.elderId
  [Senior] elderId = InMemoryFaceStorage().getElderId()

  ApiService.addTask(elderId, title, description, time, date, reminderEnabled: true)
    → POST /tasks/add
    Task.create({ elderId, title, description, time, date, reminderEnabled })
    → 201 { success: true, task }

  [Senior uniquement] _scheduleNotification(task)
    taskTime = task['time']   → "HH:mm"
    scheduledDate = taskDate à HH:mm
    warningTime = scheduledDate - 15 min
    SI warningTime passé ET taskTime futur : finalTime = now + 2s, label = "Maintenant"
    SI tout passé → skip
    MethodChannel.scheduleTask({ id, title: label, description, timestamp })

AFFICHAGE DU JOUR
──────────────────
  Calendrier strip : ← date → (navigation jour par jour)
  
  _loadTasks() → ApiService.getElderTasks(elderId, date: _selectedDate)
    → GET /tasks/elder/:id?date=ISO
    query.date = { $gte: startOfDay, $lte: endOfDay }
    Task.find(query).sort({ time: 1 })   ← tri chronologique

  Couleur carte selon mot-clé dans titre (15 catégories) :
    médicament→violet, marche→orange, repas→rouge, eau→bleu,
    douche→teal, lecture→marron, télé→indigo, appel→vert,
    sport→rose, dormir→deepPurple, musique→amber, jardin→vert foncé

  Icône adaptée (28 catégories) : medical_services, directions_walk,
    restaurant, water_drop, shower, menu_book, tv, phone, fitness_center,
    shopping_cart, bed, music_note, local_florist, church, ...

COMPLETION
───────────
  Tap carte OU swipe gauche → droite :
    
    AlertDialog (grande police pour seniors) :
      "Est-ce terminé ?" + boutons NON / OUI (pleine largeur)

    SI OUI :
      ApiService.updateTask(task['_id'], { isCompleted: true })
        → PUT /tasks/:id → Task.findByIdAndUpdate()
      MethodChannel.cancelTask({ id: task['_id'] })  ← annulation notification
      _loadTasks()   ← rechargement liste
      showSnackBar("Tâche terminée ✓", backgroundColor: green)

    Carte terminée → fond vert, texte barré, icône check verte

SUPPRESSION
────────────
  Bouton poubelle → AlertDialog confirmation
  SI confirmé :
    ApiService.deleteTask(id) → DELETE /tasks/:id
    MethodChannel.cancelTask()
    _loadTasks()
```

---

## 12. Sécurité  

| Aspect | Implémentation |
|---|---|
| Mots de passe | bcryptjs, salt factor 10, jamais stockés en clair |
| Authentification senior | Embedding facial normalisé, comparaison vectorielle (pas de photo stockée) |
| Sessions | SharedPreferences local (pas de JWT dans cette version) |
| Uploads | Multer memoryStorage → pas de fichiers sur disque serveur |
| Validation IDs MongoDB | `mongoose.Types.ObjectId.isValid()` avant chaque requête |
| Secrets | Variables d'environnement (.env), jamais en dur dans le code |
| CORS | `app.use(cors())` — à restreindre en production |
| Limite payload | `express.json({ limit: '50mb' })` pour les images base64 |

---

## 13. Déploiement

### Architecture de déploiement recommandée

```
┌──────────────────────────────────────────────────────┐
│                  Internet / Mobile                    │
│              Application Flutter APK/IPA             │
└──────────────┬──────────────────────────────────────-┘
               │ HTTPS
┌──────────────▼───────────────────────────────────────┐
│              Reverse Proxy (Nginx / Caddy)            │
│              Certificat TLS (Let's Encrypt)           │
└──────────────┬───────────────────────────────────────┘
               │
┌──────────────▼───────────────────────────────────────┐
│       Backend Node.js (PM2 / Docker container)       │
│       PORT 5000 (interne)                            │
└──────┬─────────────────────────┬────────────────────-┘
       │                         │
┌──────▼──────┐         ┌────────▼──────────────────┐
│  MongoDB    │         │  Ollama (local/container)  │
│  Atlas /    │         │  PORT 11434                │
│  self-host  │         │  modèle qwen3-vl:2b        │
└─────────────┘         └────────────────────────────┘
```

### Variables d'environnement requises

```env
# Base de données
MONGODB_URI=mongodb+srv://...

# Backend
PORT=5000
BACKEND_URL=https://votre-domaine.com

# Cloudinary
CLOUDINARY_NAME=...
CLOUDINARY_API_KEY=...
CLOUDINARY_API_SECRET=...

# SMTP (SOS email)
SMTP_USER=votrecompte@gmail.com
SMTP_PASS=votre_app_password
SMTP_TO=destinataire@email.com

# SMS fallback
SMS_TO=+21600000000

# IA
OLLAMA_URL=http://localhost:11434/api/chat
```

---

## 14. Installation & Configuration

### Backend

```bash
# Cloner et installer
cd backend
npm install

# Configurer .env (voir section Variables d'environnement)
cp .env.example .env

# Démarrer en développement
node server.js

# Démarrer en production (PM2)
pm2 start server.js --name carelink-api
```

### Ollama (IA Vision)

```bash
# Installer Ollama
curl -fsSL https://ollama.com/install.sh | sh

# Télécharger le modèle vision
ollama pull qwen3-vl:2b-instruct-q4_K_M

# Démarrer (accessible sur :11434)
ollama serve
```

### Application Flutter

```bash
# Installer les dépendances
flutter pub get

# Configurer assets/.env
echo "BACKEND_URL=https://votre-domaine.com" > assets/.env

# Build Android
flutter build apk --release

# Build iOS
flutter build ios --release
```

### Assets TFLite requis

Placer dans `assets/` :
- `mobilefacenet.tflite` — modèle reconnaissance faciale
- `classifier.tflite` — modèle classification d'objets
- `labels.txt` — étiquettes COCO correspondantes

---

## Résumé des choix techniques

| Décision | Justification |
|---|---|
| Flutter | Un seul codebase Android + iOS, performances natives, adapté aux grandes polices et accessibilité |
| Node.js + Express | Léger, async natif, excellent avec Socket.IO, écosystème npm riche |
| MongoDB | Schéma flexible (embeddings faciaux comme tableaux, profils évolutifs), bon pour le prototypage |
| Socket.IO | Abstraction WebSocket simple, gestion automatique des rooms, reconnexion automatique |
| TFLite on-device | Fonctionne sans Internet, latence nulle, confidentialité (embeddings jamais envoyés en clair) |
| Ollama | IA vision open-source auto-hébergeable, pas de coût API, contrôle total des données |
| Cloudinary | CDN fiable, upload streaming sans disque local, support audio/vidéo natif |
| bcryptjs | Standard de hachage éprouvé, sel aléatoire par défaut |
| Authentification faciale | Adapté aux personnes âgées (pas de mot de passe à mémoriser), identification par similarité cosinus |
