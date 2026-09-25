# IZAHAY — test Flutter/Android avec Docker

Ce dossier est **un projet de démarrage** : `app/` ne contient pas encore les fichiers Flutter générés. Le premier lancement crée un projet Android, y copie l'écran de test puis compile un APK. Les lancements suivants recompilent vos modifications dans `app/lib/main.dart`.

## Prérequis

- macOS (Intel ou Apple Silicon) / Windows 10–11 avec Docker Desktop démarré, ou Linux avec Docker Engine **et le plugin Docker Compose**.
- Connexion Internet au premier lancement et suffisamment d'espace disque pour l'image Flutter et les dépendances Android (prévoir plusieurs Go).
- Sous Windows, Docker Desktop configuré avec le moteur Linux/WSL2. Les commandes ci-dessous s'exécutent dans PowerShell, Terminal macOS ou un terminal Linux.
- Sur Linux, votre compte doit être autorisé à utiliser Docker ; sinon utilisez `sudo docker compose ...` si votre installation l'exige.

## Construire l'APK

Ouvrez un terminal **dans le dossier qui contient `docker-compose.yml`**, puis lancez :

```sh
docker compose run --rm android
```

Le premier démarrage télécharge l'image et les dépendances : il peut être long. En cas de succès, retrouvez l'APK ici :

```text
app/build/app/outputs/flutter-apk/app-debug.apk
```

Pour reconstruire après une modification de `app/lib/main.dart`, relancez **la même commande**. Si une compilation échoue, lisez le message d'erreur dans le terminal : aucun APK neuf n'est garanti dans ce cas.

## Installer sur votre Android sans ADB

Transférez `app-debug.apk` sur votre téléphone (Drive, partage réseau, etc.), ouvrez-le depuis le téléphone et autorisez l'installation depuis cette source uniquement si vous lui faites confiance. Lors des mises à jour du même projet, Android devrait permettre l'installation par-dessus l'ancienne version tant que son identifiant et sa signature de débogage n'ont pas changé.

## Utilisation et limites

- Le dossier `app/` est créé automatiquement au premier lancement. **Ne supprimez pas `app/` après y avoir mis votre code.**
- Le conteneur permet la compilation Android, pas l'interface graphique Android Studio, l'émulateur Android, ni le débogage USB du téléphone depuis Docker Desktop sur Mac/Windows.
- L'image `ghcr.io/cirruslabs/flutter:3.44.0` est épinglée pour éviter les surprises liées au tag `latest`. Son éditeur a annoncé la fin des mises à jour de ses images en mai 2026 ; pour un projet durable, il faudra envisager une image Flutter maintenue ou un Dockerfile propre.
- Sur Linux, les fichiers générés dans `app/` peuvent appartenir à root, car le conteneur s'exécute en root. Pour corriger les droits sur *ce dossier uniquement* : `sudo chown -R "$(id -u):$(id -g)" app`.
- Flutter utilise un cache de paquets et Gradle utilise son propre volume Docker, conservés entre les builds.
