# SENSIA — Changelog IA / Reconnaissance sonore

## Fichiers créés

| Fichier | Rôle |
|---------|------|
| `app/lib/services/audio_capture_service.dart` | Capture micro (PCM 16-bit, 16kHz, mono) |
| `app/lib/services/audio_preprocessing_service.dart` | Conversion PCM → Float32, frames chevauchantes |
| `app/lib/services/yamnet_service.dart` | Inférence YAMNet locale (521 classes) |
| `app/lib/services/sound_filter_service.dart` | Filtre IZAHAY, EMA, priorité vibration |
| `app/lib/models/audio_frame.dart` | Modèle d'une frame audio |
| `app/lib/models/sound_detection_result.dart` | Résultat structuré d'une détection |
| `app/lib/config/sound_priority_config.dart` | Configuration des 13 catégories surveillées |
| `app/lib/screens/microphone_test_screen.dart` | Écran test micro |
| `app/lib/screens/preprocessing_test_screen.dart` | Écran test preprocessing |
| `app/lib/screens/yamnet_test_screen.dart` | Écran test YAMNet brut |
| `app/lib/screens/detection_test_screen.dart` | Écran test détections filtrées |

## Fichiers modifiés

| Fichier | Changement |
|---------|------------|
| `app/lib/main.dart` | Pointe vers `DetectionTestScreen` |
| `app/pubspec.yaml` | Ajout `record`, `permission_handler`, `tflite_flutter`, assets YAMNet |
| `app/android/app/build.gradle.kts` | `minSdk = 24`, Java/Kotlin 17 |
| `app/android/build.gradle.kts` | `gradle.afterProject` pour forcer compileSdk 36 + JVM 17 sur plugins |
| `app/android/gradle.properties` | `kotlin.jvm.target.validation.mode=warning`, `android.uniquePackageNames=false` |
| `app/android/app/src/main/AndroidManifest.xml` | Permission `RECORD_AUDIO`, label "SENSIA" |
| `scripts/build.sh` | Téléchargement modèle YAMNet + labels, copie APK en SENSIA-debug.apk |

## Architecture du pipeline

```
Microphone (PCM 16-bit, 16kHz, mono)
    │
    ▼
AudioPreprocessingService
    │  Conversion Float32, frames de 15600 samples
    │  Hop = 8000 samples (0.5s) → 2 frames/seconde
    ▼
YamnetService
    │  Inférence locale TFLite → 521 scores
    ▼
SoundFilterService
    │  Filtre 13 catégories IZAHAY
    │  EMA (moyenne mobile exponentielle)
    │  Attribution priorité vibration 1-5
    ▼
SoundDetectionResult (JSON structuré)
```

## Les 13 catégories surveillées

| Priorité | Catégorie | Classes YAMNet |
|----------|-----------|----------------|
| 5 | `train` | Train, Train horn, Train whistle |
| 5 | `fire_alarm` | Fire alarm |
| 5 | `smoke_alarm` | Smoke detector, smoke alarm |
| 4 | `car_horn` | Vehicle horn/car horn/honking, Toot, Air horn/truck horn |
| 4 | `emergency_siren` | Siren, Civil defense siren, Police car, Ambulance, Fire engine, Emergency vehicle |
| 4 | `car_alarm` | Car alarm |
| 3 | `baby_cry` | Baby cry/infant cry, Crying/sobbing |
| 3 | `alarm` | Alarm, Buzzer |
| 2 | `doorbell` | Doorbell, Ding-dong |
| 2 | `door_knock` | Knock |
| 2 | `telephone` | Telephone, Telephone bell ringing, Ringtone |
| 2 | `alarm_clock` | Alarm clock |
| 1 | `dog_bark` | Bark, Yip, Bow-wow |

## Système EMA (Moyenne Mobile Exponentielle)

Formule : `EMA = alpha × score_actuel + (1 - alpha) × EMA_précédent`

- `alpha = 0.4` (réactivité)
- `threshold = 0.30` (seuil de confirmation)

### Exemple concret : klaxon de train intermittent

```
Fenêtre 1 (0.0s) : score brut = 0.80 → EMA = 0.32 → DÉTECTÉ (0.32 > 0.30)
Fenêtre 2 (0.5s) : score brut = 0.02 → EMA = 0.20 → non affiché
Fenêtre 3 (1.0s) : score brut = 0.75 → EMA = 0.42 → DÉTECTÉ
Fenêtre 4 (1.5s) : score brut = 0.03 → EMA = 0.26 → non affiché
Fenêtre 5 (2.0s) : score brut = 0.82 → EMA = 0.48 → DÉTECTÉ
Fenêtre 6 (2.5s) : score brut = 0.78 → EMA = 0.60 → DÉTECTÉ
Fenêtre 7 (3.0s) : score brut = 0.02 → EMA = 0.37 → DÉTECTÉ (encore visible)
Fenêtre 8 (3.5s) : score brut = 0.01 → EMA = 0.22 → non affiché
```

L'EMA monte vite avec les détections et redescend lentement pendant les pauses.

### Exemple : deux sons simultanés

```
Train horn : score 0.82 → EMA 0.45 → priorité 5
Dog bark   : score 0.88 → EMA 0.51 → priorité 1

Les deux sont conservés. La priorité 5 ne supprime PAS le dog_bark.
```

## Sortie JSON

```json
[
  {
    "category": "train",
    "yamnetClass": "Train horn",
    "score": 0.82,
    "confirmed": true,
    "vibrationPriority": 5,
    "timestamp": "2026-09-26T08:30:00.000"
  },
  {
    "category": "dog_bark",
    "yamnetClass": "Bark",
    "score": 0.88,
    "confirmed": true,
    "vibrationPriority": 1,
    "timestamp": "2026-09-26T08:30:00.000"
  }
]
```

## Commande de build

```bash
cd SENSIA && docker compose up --build
```

APK généré : `app/build/app/outputs/flutter-apk/SENSIA-debug.apk`
