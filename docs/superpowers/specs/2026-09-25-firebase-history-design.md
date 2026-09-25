# Module Firebase et historique IZAHAY — design

Date: 2026-09-25
Auteur: Personne 3 (moteur de vibrations, traitement des événements, Firebase, historique, simulation)
Statut: approuvé pour implémentation

## Contexte

Troisième module de la personne 3, après le moteur de vibrations
([2026-09-25-haptic-engine-design.md](2026-09-25-haptic-engine-design.md))
et le traitement des événements sonores
([2026-09-25-sound-event-processor-design.md](2026-09-25-sound-event-processor-design.md)),
tous deux livrés, testés et déjà revus.

Ce module ajoute la persistance : enregistrer, récupérer et supprimer les
événements sonores validés (ceux qui ont réellement déclenché une
vibration), ainsi que les préférences de vibration, via Firebase (Cloud
Firestore + Firebase Authentication).

État du projet au moment de l'écriture : aucune trace de Firebase dans le
code (aucune dépendance, aucun fichier de configuration, aucune
authentification). Aucun projet Firebase partagé par l'équipe n'existe
encore (vérifié avec l'auteur).

## Décisions validées avec l'auteur

1. **Aucun projet Firebase n'existe** — sa création dans la console
   Firebase est une étape manuelle (voir "Configuration manuelle"
   ci-dessous), impossible à automatiser depuis ce terminal (nécessite une
   connexion navigateur à un compte Google).
2. **Authentification : Firebase Anonymous Auth.** Aucun écran de
   connexion requis (l'écran serait du ressort de la personne 2, qui n'a
   rien livré de tel) ; chaque installation obtient un identifiant Firebase
   stable dès le premier lancement, migrable plus tard vers un compte réel
   sans changer ce module.
3. **Cloud Firestore**, pas Realtime Database — aucune techno déjà
   adoptée par l'équipe ; Firestore correspond à la structure proposée par
   l'auteur (`users/{userId}/events/{eventId}`) et s'interroge/pagine plus
   proprement qu'une base temps réel pour un historique.
4. **Tests contre le Firebase Local Emulator Suite, réellement exécutés**
   (pas seulement documentés) : `node`/`npm` sont disponibles dans
   l'environnement de développement, le registre npm est joignable, donc
   `firebase-tools` peut être installé via `npx` et les émulateurs
   Firestore + Auth lancés en local avec un projet `demo-izahay` — **sans
   compte Firebase réel ni connexion navigateur**. Cela permet de tester
   pour de vrai les règles de sécurité (impossible avec un simple double
   en mémoire, puisque les règles de sécurité ne sont pas du code Dart).

## Objectifs

1. Enregistrer un événement sonore validé (= qui a réellement déclenché
   une vibration).
2. Récupérer l'historique de l'utilisateur courant, du plus récent au
   plus ancien.
3. Supprimer un événement individuel.
4. Effacer tout l'historique, avec un comportement explicite si des
   écritures sont encore en attente de synchronisation hors-ligne.
5. Enregistrer et récupérer les préférences de vibration (réglages par
   catégorie déjà définis par le module de traitement des événements).
6. Gérer proprement les erreurs de lecture/écriture, jamais d'exception
   non typée.
7. Distinguer événements réels et simulés dans l'historique.
8. Fonctionner hors-ligne pour la persistance (cache et file d'écriture
   Firestore natifs), sans qu'aucune vibration ne dépende d'une réponse
   Firebase.
9. Isoler les données par utilisateur avec des règles de sécurité
   Firestore strictes (moindre privilège).

## Non-objectifs

- Pas d'écran d'historique ni de réglages (personne 2).
- Pas de modification du modèle IA.
- Pas de stockage local complémentaire (Hive/sqlite...) : la persistance
  hors-ligne native de Firestore suffit à ce périmètre.
- Pas de pagination par curseur pour l'historique dans cette première
  version (YAGNI) : une limite fixe (`fetchEvents({int limit = 100})`)
  suffit ; une pagination pourra être ajoutée plus tard sans changer
  l'interface `HistoryRepository`.
- Pas de compte utilisateur complet (email/Google) — voir décision n°2.

## Architecture

```
lib/history/
├── models/
│   └── sound_event_record.dart        # id (généré client) + SoundEvent existant, pas de duplication de champs
├── history_exceptions.dart            # HistoryWriteException, HistoryReadException, HistoryPermissionException
├── current_user.dart                  # Connexion anonyme Firebase, expose l'uid courant
├── history_repository.dart            # Interface abstraite de persistance
├── firestore_history_repository.dart  # Implémentation réelle (Cloud Firestore)
├── history_result_sink.dart           # Adaptateur : implémente HistorySink (côté sound_events), ne persiste que les SoundEventResult au statut `triggered`
└── history_debug_main.dart            # Point d'entrée séparé pour test manuel (même pattern que haptics_debug_main.dart)
```

### Modifications ciblées de `lib/sound_events/` (déjà livré)

Requises explicitement par le besoin d'intégration ("le moteur de
traitement doit pouvoir transmettre un événement validé au module
d'historique sans connaître Firebase") — additives et rétrocompatibles,
aucun test existant cassé :

- **Nouveau** `lib/sound_events/history_sink.dart` : interface abstraite
  minimale `HistorySink { Future<void> record(SoundEventResult result); }`,
  définie côté consommateur (`sound_events`) pour qu'il ne dépende jamais
  de Firebase — seul `history` l'implémente (inversion de dépendance).
- **Modifié** `lib/sound_events/sound_event_processor.dart` : paramètre de
  constructeur optionnel `HistorySink? historySink` (défaut `null`).
  Après un résultat `triggered`, appel **fire-and-forget** (jamais
  `await`é dans le pipeline) — un Firestore lent ou hors-ligne ne peut
  donc jamais retarder ni faire échouer le déclenchement d'une vibration
  (objectif n°8).
- **Modifié** `lib/sound_events/category_settings.dart` : ajout d'un
  getter `Map<String, CategorySettings> get all` (lecture seule) pour que
  le module historique puisse sérialiser les préférences sans dupliquer
  le modèle `CategorySettings`.

`lib/haptics/**` et `lib/main.dart` restent inchangés.

### Modèle de données (`sound_event_record.dart`)

```dart
class SoundEventRecord {
  final String id;        // généré côté client via collection.doc().id
  final SoundEvent event; // réutilise le modèle existant, pas de duplication
}
```

Seuls les résultats `SoundEventStatus.triggered` sont convertis en
`SoundEventRecord` par `HistoryResultSink` — un événement filtré,
supplanté ou en échec n'a jamais été vécu par l'utilisateur, il n'a pas sa
place dans son historique.

### Structure Firestore

```
users/
  {userId}/
    settings/
      vibrations          # un seul document : { "<catégorie>": {enabled, threshold, requiredConfirmations, cooldownSeconds}, ... }
    events/
      {eventId}           # { category, score, timestamp, source, isSimulation }
```

`eventId` = id généré côté client (`collection.doc().id`), jamais
`.add()` : une même écriture retentée écrase le même document au lieu
d'en créer un doublon (objectif "éviter les doublons lors de la
synchronisation").

`cooldown` (un `Duration` côté Dart) est stocké en secondes entières
(`cooldownSeconds`), Firestore n'ayant pas de type Duration natif.

### `HistoryRepository` (interface)

```dart
abstract class HistoryRepository {
  Future<void> saveEvent(SoundEventRecord record);
  Future<List<SoundEventRecord>> fetchEvents({int limit = 100});
  Future<void> deleteEvent(String eventId);
  Future<void> clearHistory();
  Future<void> saveVibrationPreferences(Map<String, CategorySettings> preferences);
  Future<Map<String, CategorySettings>?> fetchVibrationPreferences(); // null si jamais enregistrées
}
```

`FirestoreHistoryRepository` l'implémente via Cloud Firestore.
`fetchEvents` trie par `timestamp` décroissant (plus récents en premier).

### Comportement explicite : `clearHistory()` avec écritures en attente

Le SDK Firestore ne peut pas annuler une écriture déjà mise en file
d'attente hors-ligne. `clearHistory()` supprime les événements connus
(présents dans le cache/serveur) au moment de l'appel ; une écriture pour
un **nouvel** événement déjà en file d'attente au moment du clear se
synchronisera quand même ensuite et réapparaîtra dans l'historique. C'est
une limitation documentée, pas un oubli : une garantie plus forte
nécessiterait une Cloud Function côté serveur (hors périmètre — pas de
nouvelle dépendance/complexité non nécessaire ici).

### Erreurs (`history_exceptions.dart`)

- `HistoryWriteException` — échec d'écriture (réseau, quota...), enveloppe
  la `FirebaseException` d'origine.
- `HistoryReadException` — échec de lecture, même principe.
- `HistoryPermissionException` — accès refusé (`FirebaseException.code ==
  'permission-denied'`), typiquement une tentative d'accès aux données
  d'un autre utilisateur bloquée par les règles de sécurité.

Aucune exception générique non typée ne doit remonter aux appelants —
même philosophie que les deux modules précédents.

### Authentification (`current_user.dart`)

```dart
class CurrentUser {
  /// Retourne l'uid de l'utilisateur courant, en le connectant
  /// anonymement via Firebase Auth si ce n'est pas déjà fait.
  Future<String> ensureSignedIn();
}
```

Aucun identifiant n'est inventé ni codé en dur : l'uid vient uniquement de
`FirebaseAuth`.

### Règles de sécurité Firestore (`firestore.rules`, nouveau fichier à la
racine du dépôt)

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId}/events/{eventId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    match /users/{userId}/settings/vibrations {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

Moindre privilège strict : un utilisateur ne peut lire/écrire que sous son
propre `userId`, et uniquement les chemins `events`/`settings/vibrations`
— pas de lecture publique, pas de joker `{document=**}` (voir addendum
post-revue : la version initiale avec joker isolait correctement les
utilisateurs entre eux, mais permettait à un utilisateur d'écrire
n'importe quelle forme de document sous son propre uid).

## Stratégie de tests — deux niveaux

**Tests unitaires purs** (`flutter test`, aucun réseau requis), avec un
`FakeHistoryRepository` en mémoire (même pattern que
`FakeVibrationExecutor`) :
- Enregistrement d'un événement réel et d'un événement simulé (tests 1-2).
- Récupération triée du plus récent au plus ancien (test 3).
- Suppression d'un événement, effacement de l'historique (tests 5, 9→
  côté logique de tri/état, pas règles de sécurité).
- Dédoublonnage : enregistrer deux fois le même `SoundEventRecord.id` ne
  produit qu'une entrée (test 8).
- `SoundEventProcessor` + `HistorySink` : un déclenchement appelle
  `record()` sans jamais l'attendre — testable en injectant un
  `HistorySink` factice qui bloque indéfiniment, et en vérifiant que
  `process()` retourne quand même son résultat sans attendre (objectif
  n°8, "les vibrations fonctionnent même si Firebase est inaccessible").

**Tests contre le Firebase Local Emulator Suite** (`integration_test/`,
nécessite `firebase-tools` via `npx`, émulateurs Firestore+Auth lancés en
local avec le projet `demo-izahay`, aucun compte réel) :
- Écriture et lecture réelles d'un événement (round-trip Firestore).
- Persistance après redémarrage du client (relire après avoir recréé
  l'instance `FirebaseFirestore`, cache local encore présent).
- Comportement hors-ligne → en ligne : `disableNetwork()` puis écriture
  (mise en file d'attente), puis `enableNetwork()` et vérification de la
  synchronisation.
- **Test 9 — refus d'accès aux données d'un autre utilisateur** : connecté
  en tant qu'utilisateur A, tentative de lecture/écriture sous le chemin
  de l'utilisateur B → `HistoryPermissionException`, contre les vraies
  règles de sécurité de `firestore.rules` appliquées par l'émulateur (pas
  une simulation Dart).

## Configuration manuelle requise (hors de portée de ce terminal)

1. Créer un projet Firebase dans la console (nécessite un compte Google,
   une action navigateur — ne peut pas être automatisée ici).
2. Activer Cloud Firestore et Firebase Authentication (méthode anonyme)
   dans ce projet.
3. Exécuter `flutterfire configure` (CLI FlutterFire, nécessite une
   connexion au compte Firebase) pour générer `lib/firebase_options.dart`
   et les fichiers de configuration Android (`google-services.json`).
4. Déployer les règles de sécurité : `firebase deploy --only
   firestore:rules`.
5. Appeler `Firebase.initializeApp(options:
   DefaultFirebaseOptions.currentPlatform)` au tout début du vrai point
   d'entrée de l'application (`lib/main.dart`, quand la personne 2 le fera
   évoluer au-delà de l'écran de test actuel) — ce module ne modifie pas
   `lib/main.dart` lui-même.

## Points d'intégration avec les autres modules

- **`SoundEventProcessor`** (déjà livré) : reçoit un `HistorySink?`
  optionnel, lui transmet chaque événement `triggered` sans jamais
  connaître Firebase.
- **Personne 2 (UI historique et réglages)** : consomme
  `HistoryRepository.fetchEvents`/`deleteEvent`/`clearHistory` pour
  l'écran d'historique, et
  `saveVibrationPreferences`/`fetchVibrationPreferences` pour un futur
  écran de réglages.
- **Personne 1 (IA)** : aucun point d'intégration direct, ce module ne
  connaît que le contrat `SoundEvent` déjà partagé.

## Addendum post-revue

La revue finale du module (agent indépendant, exécutée contre le vrai
émulateur) a trouvé et fait corriger plusieurs points non anticipés par ce
document :

- **Règles de sécurité resserrées** à des chemins explicites (`events`,
  `settings/vibrations`) plutôt qu'un joker `{document=**}` — voir la
  section règles de sécurité ci-dessus.
- **`CurrentUser.ensureSignedIn()` est maintenant sûr face aux appels
  concurrents** au tout premier lancement : sans ce correctif, deux appels
  arrivant avant la fin de la toute première connexion anonyme pouvaient
  créer deux comptes distincts, l'un d'eux se retrouvant ensuite à écrire
  sous un chemin dont il n'est plus authentifié (rejeté silencieusement
  par les règles de sécurité, via le fire-and-forget du sink).
- **Le sink d'historique de `SoundEventProcessor` capture aussi les
  exceptions synchrones**, pas seulement celles d'un `Future` rejeté :
  une implémentation de `HistorySink` mal écrite (non `async`) ne peut
  plus faire échouer `process()` après coup.
- **`clearHistory()` supprime par blocs de 400** plutôt qu'en un seul lot
  (la limite Firestore est de 500 opérations par lot) : un historique de
  plus de 500 événements ne bloque plus l'effacement.
- **Un document Firestore malformé** (schéma incompatible, donnée
  corrompue) produit désormais `HistoryReadException`, jamais une
  `TypeError` non typée.
- **Erreurs du sink journalisées** (`dart:developer`) plutôt
  qu'entièrement silencieuses, pour qu'une mauvaise configuration Firebase
  (règles non déployées, Auth anonyme désactivée...) laisse au moins une
  trace de débogage, même si l'historique reste volontairement muet côté
  utilisateur/vibrations.

Voir le ledger d'exécution pour le détail complet des correctifs, des
vérifications réelles contre l'émulateur, et des points mineurs
volontairement différés (arrondi des `Duration`/`Timestamp`, constante
d'hôte d'émulateur codée en dur, etc.).
