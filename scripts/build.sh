#!/usr/bin/env bash
set -Eeuo pipefail
cd /workspace/app

if [[ ! -f pubspec.yaml ]]; then
  echo '==> Création du projet Flutter Android IZAHAY...'
  flutter create --platforms=android --project-name=izahay --org=mg.izahay .
  cp /workspace/template/main.dart lib/main.dart
fi

# --- Download YAMNet model and labels ---
MODELS_DIR="/workspace/app/assets/models"
mkdir -p "$MODELS_DIR"

if [[ ! -f "$MODELS_DIR/yamnet.tflite" ]]; then
  echo '==> Téléchargement du modèle YAMNet...'
  curl -L -f -o "$MODELS_DIR/yamnet.tflite" \
    "https://tfhub.dev/google/lite-model/yamnet/tflite/1?lite-format=tflite" || {
      echo "ERREUR: Impossible de télécharger le modèle YAMNet"
      exit 1
    }
  echo "==> Modèle YAMNet téléchargé ($(wc -c < "$MODELS_DIR/yamnet.tflite") octets)"
fi

if [[ ! -f "$MODELS_DIR/yamnet_class_map.csv" ]]; then
  echo '==> Téléchargement des labels YAMNet...'
  curl -L -f -o "$MODELS_DIR/yamnet_class_map.csv" \
    "https://raw.githubusercontent.com/tensorflow/models/master/research/audioset/yamnet/yamnet_class_map.csv" || \
  curl -L -f -o "$MODELS_DIR/yamnet_class_map.csv" \
    "https://raw.githubusercontent.com/tensorflow/models/main/research/audioset/yamnet/yamnet_class_map.csv" || {
      echo "ERREUR: Impossible de télécharger les labels YAMNet"
      exit 1
    }
  echo '==> Labels YAMNet téléchargés'
fi

echo '==> Installation/vérification des dépendances...'
flutter pub get

echo '==> Compilation de l APK Android (debug)...'
flutter build apk --debug

APK_SRC="build/app/outputs/flutter-apk/app-debug.apk"
APK_DST="build/app/outputs/flutter-apk/SENSIA-debug.apk"
cp "$APK_SRC" "$APK_DST"

echo "==> APK prêt : app/$APK_DST"
