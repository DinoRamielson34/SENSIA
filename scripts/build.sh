#!/usr/bin/env bash
set -Eeuo pipefail
cd /workspace/app

if [[ ! -f pubspec.yaml ]]; then
  echo '==> Création du projet Flutter Android IZAHAY...'
  flutter create --platforms=android --project-name=izahay --org=mg.izahay .
  cp /workspace/template/main.dart lib/main.dart
fi

echo '==> Installation/vérification des dépendances...'
flutter pub get

echo '==> Compilation de l’APK Android (debug)...'c
flutter build apk --debug

echo '==> APK prêt : app/build/app/outputs/flutter-apk/app-debug.apk'
