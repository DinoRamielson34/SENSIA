# Moteur de traitement des événements sonores IZAHAY — design

Date: 2026-09-25
Auteur: Personne 3 (moteur de vibrations, traitement des événements, Firebase, historique, simulation)
Statut: approuvé pour implémentation

## Contexte

Suite du module précédent ([2026-09-25-haptic-engine-design.md](2026-09-25-haptic-engine-design.md)) : IZAHAY reconnaît des sons et les traduit en vibrations. Le moteur de vibrations (`lib/haptics/`) existe déjà, complet et testé (`HapticEngine`, `VibrationExecutor`, `PatternRegistry`...). Ce document couvre le second module de la personne 3 : le **moteur de traitement des événements sonores**, qui reçoit les résultats de reconnaissance sonore et décide si — et comment — déclencher une vibration.

Ce module doit fonctionner indépendamment du modèle IA (personne 1) et de Firebase, et être testable avec des événements fictifs, sans microphone.

État du projet au moment de l'écriture : `lib/haptics/` complet (voir spec précédente). Aucun modèle d'événement sonore, aucune configuration runtime (seuils/délais) n'existe encore dans le code. Vérifié : il n'y a pas de structure de données commune existante à réutiliser pour l'événement — celle définie ici est nouvelle.

## Objectifs

Un moteur qui, pour chaque événement de reconnaissance sonore reçu :

1. Vérifie que la catégorie est prise en charge (connue du système).
2. Vérifie que l'utilisateur a activé cette catégorie.
3. Compare le score au seuil configuré pour la catégorie.
4. Confirme sur plusieurs détections consécutives quand la catégorie l'exige.
5. Applique un délai anti-répétition par catégorie pour éviter les rafales.
6. Reste cohérent si deux catégories déclenchent presque simultanément.
7. Récupère et déclenche le motif de vibration associé, via le moteur haptique existant.
8. Produit un résultat exploitable par les autres modules (UI, historique).
9. Bloque les nouveaux événements microphone après l'arrêt de l'écoute.
10. Distingue clairement les événements réels des événements simulés.
11. Permet de modifier seuils/délais/activation à l'exécution, sans recompiler.

## Non-objectifs

- Pas de modification du moteur haptique (`lib/haptics/`) — il est réutilisé tel quel, sans changement.
- Pas de modification des écrans des autres développeurs.
- Pas d'implémentation ou de dépendance directe au modèle IA — seul le contrat de données `SoundEvent` est partagé.
- Pas d'intégration Firebase ni de persistance des réglages (futur module de la personne 3).
- Pas de migration de framework : Flutter/Dart, mêmes conventions que `lib/haptics/`.

## Décisions de conception (validées)

1. **Aucune modification de `HapticEngine`/`PatternRegistry`.** Ce module possède son propre catalogue de catégories connues (`SoundEventSettings`), indépendant du registre de motifs du moteur haptique. Au moment de déclencher, si les deux catalogues sont désynchronisés, `HapticEngine.playForCategory` lève `InvalidVibrationPatternException` — capturée et traduite en résultat "non déclenché", sans dupliquer de logique de recherche.
2. **Pas de nouvelle interface/abstraction pour parler au moteur haptique.** `HapticEngine` est déjà la façade testable (via son propre `FakeVibrationExecutor`, réutilisable ici). Le processor en dépend directement, injecté au constructeur. Ajouter une interface par-dessus serait une duplication sans gain de testabilité.
3. **Confirmation par compteur consécutif, sans fenêtre temporelle.** N détections qualifiantes (score ≥ seuil) d'affilée pour la même catégorie déclenchent ; une détection sous le seuil remet le compteur à zéro. Pas de délai maximal entre détections à calibrer (YAGNI, aucune valeur fournie dans la demande).
4. **Les événements simulés (`isSimulation: true`) ignorent l'état d'écoute.** Seuls les événements `source: "microphone"` sont bloqués par l'arrêt de l'écoute — la simulation sert justement à tester le moteur sans microphone.
5. **Concurrence entre catégories déjà gérée par `HapticEngine`** ("dernier gagne", testé dans le module précédent). Le processor n'a rien à réimplémenter : chaque événement validé appelle simplement `playForCategory`.
6. **Résultats métier normaux, jamais des exceptions.** "Catégorie désactivée", "sous le seuil", "en attente de confirmation", etc. sont des issues normales du pipeline, retournées via `SoundEventResult` — jamais levées comme exceptions Dart. Seules les erreurs de programmation restent des exceptions classiques.
7. **Valeurs de seuil/délai expérimentales, pas scientifiquement validées.** Les valeurs par défaut (seuil 0,75, anti-répétition 5s) sont des points de départ explicitement documentés comme tels dans le code, modifiables sans recompiler (voir `SoundEventSettings`).

## Architecture

Nouveau dossier `lib/sound_events/`, séparation stricte des responsabilités :

```
lib/sound_events/
├── sound_event.dart          # Le contrat de données reçu de l'IA (et du mode simulation)
├── category_settings.dart    # Réglages par catégorie : seuil, activé, confirmations, anti-répétition
├── sound_event_result.dart   # Le verdict du traitement, exploitable par les autres modules
└── sound_event_processor.dart # Le pipeline : orchestration des 8 étapes
```

### Modèle de données (`sound_event.dart`)

```dart
class SoundEvent {
  final String category;      // catégorie sonore reconnue, ex: "dog_bark"
  final double score;         // score du modèle IA — PAS une probabilité calibrée
  final DateTime timestamp;   // date/heure de détection
  final String source;        // origine, ex: "microphone", "simulation"
  final bool isSimulation;    // true si l'événement est injecté pour test/démo
}
```

Correspond exactement à l'exemple fourni. Aucune structure commune existante n'a été modifiée : celle-ci est nouvelle.

### Réglages par catégorie (`category_settings.dart`)

```dart
class CategorySettings {
  final bool enabled;
  final double threshold;           // 0.0 à 1.0
  final int requiredConfirmations;  // >= 1 ; 1 = pas de confirmation multi-fenêtres
  final Duration cooldown;          // délai anti-répétition
}

class SoundEventSettings {
  // Table mutable catégorie -> CategorySettings, modifiable à l'exécution
  // (règle 12). Absence d'entrée = catégorie inconnue du système (test 5).
}
```

- Seedée avec `sonnette` et `aboiement` (mêmes catégories que les motifs par défaut du moteur haptique, pour cohérence), valeurs expérimentales : `enabled: true, threshold: 0.75, requiredConfirmations: 1, cooldown: Duration(seconds: 5)`.
- `updateCategory(category, settings)` : ajoute ou remplace les réglages d'une catégorie — c'est le point d'extension par lequel une future UI de réglages ou une synchronisation Firebase pourra modifier seuils/délais sans toucher au code de ce module.
- `lookup(category) -> CategorySettings?` : `null` si catégorie inconnue.

### Résultat (`sound_event_result.dart`)

```dart
enum SoundEventStatus {
  triggered,           // vibration déclenchée
  unknownCategory,     // catégorie absente de SoundEventSettings (test 5)
  categoryDisabled,    // CategorySettings.enabled == false (test 2)
  belowThreshold,      // score < seuil (test 3)
  awaitingConfirmation,// confirmations requises pas encore atteintes
  inCooldown,          // anti-répétition actif pour cette catégorie (test 4)
  listeningStopped,    // événement microphone reçu après stopListening() (test 7)
  hapticFailure,       // HapticEngine a rejeté/échoué le déclenchement
  superseded,          // supplanté par une autre demande chez HapticEngine avant d'avoir réellement vibré
}

class SoundEventResult {
  final SoundEvent event;
  final SoundEventStatus status;
  final bool isSimulation;   // dupliqué depuis event, pour lisibilité côté consommateurs (règle 10)
  final String? reason;      // message lisible, notamment pour hapticFailure
}
```

Toujours retourné par `process()` — jamais d'exception pour une issue métier normale.

### Pipeline (`sound_event_processor.dart`)

```dart
class SoundEventProcessor {
  SoundEventProcessor({
    required HapticEngine hapticEngine,
    SoundEventSettings? settings,
  });

  void startListening();
  void stopListening();

  Future<SoundEventResult> process(SoundEvent event);
}
```

`process()` exécute, dans l'ordre, 8 fonctions privées courtes (une classe orchestratrice, pas une classe par étape — éviter la sur-abstraction pour ce périmètre) :

1. **Porte d'écoute** : si `event.source == "microphone"` et `stopListening()` a été appelé, retourne `listeningStopped` immédiatement. Les événements `isSimulation: true` passent toujours cette porte, quel que soit l'état d'écoute (décision validée n°4).
2. **Catégorie connue** : `settings.lookup(event.category)` ; `null` → `unknownCategory`.
3. **Catégorie activée** : `CategorySettings.enabled` ; `false` → `categoryDisabled`.
4. **Seuil** : `event.score >= CategorySettings.threshold` ; sinon `belowThreshold`, **et remet le compteur de confirmation de cette catégorie à zéro** (décision validée n°3 : un événement sous le seuil casse la série).
5. **Confirmation** : incrémente un compteur interne par catégorie ; si `< requiredConfirmations`, retourne `awaitingConfirmation` (compteur non remis à zéro, il continue à progresser au prochain événement qualifiant).
6. **Anti-répétition** : si un déclenchement a eu lieu pour cette catégorie il y a moins de `cooldown`, retourne `inCooldown` **sans remettre le compteur de confirmation à zéro** (l'événement était valide, juste trop rapproché).
7. **Déclenchement haptique** : `await hapticEngine.playForCategory(event.category)`. En cas de succès, réinitialise le compteur de confirmation de cette catégorie et enregistre l'heure de déclenchement (pour l'anti-répétition suivant), retourne `triggered`. En cas de `InvalidVibrationPatternException` ou `HapticUnsupportedException`, retourne `hapticFailure` avec le message de l'exception dans `reason` — jamais propagée à l'appelant.
8. Le résultat de chaque étape est toujours un `SoundEventResult` — c'est la sortie exploitable par les autres modules (règle 8).

**État interne** : deux tables privées par catégorie — compteur de confirmation (`Map<String, int>`) et heure du dernier déclenchement réussi (`Map<String, DateTime>`). Aucun état partagé entre catégories : une rafale d'aboiements ne bloque pas une sonnette qui suit.

**Concurrence (règle 6 / test 8)** : aucune logique propre au processor. Deux `process()` sur des catégories différentes appellent chacun `hapticEngine.playForCategory`, dont la politique "dernier gagne" (testée dans le module précédent) garantit qu'une seule vibration cohérente est produite, sans réimplémentation ici.

## Fichiers créés

- `app/lib/sound_events/sound_event.dart`
- `app/lib/sound_events/category_settings.dart`
- `app/lib/sound_events/sound_event_result.dart`
- `app/lib/sound_events/sound_event_processor.dart`
- `app/test/sound_events/sound_event_processor_test.dart`

## Fichiers modifiés

Aucun. `lib/haptics/**`, `lib/main.dart` et tous les fichiers des autres développeurs restent inchangés.

## Stratégie de tests

Tous les tests sont des tests unitaires purs (`flutter test`, aucun device requis), avec un `HapticEngine` réel branché sur le `FakeVibrationExecutor` déjà existant (`test/haptics/fake_vibration_executor.dart`) — aucun microphone ni IA nécessaire.

- **Test 1** : catégorie activée, score ≥ seuil, `requiredConfirmations: 1` → `triggered`, `FakeVibrationExecutor.vibrateCalls` non vide.
- **Test 2** : catégorie connue mais `enabled: false` → `categoryDisabled`, aucun appel à l'executor.
- **Test 3** : score < seuil → `belowThreshold`, aucun appel à l'executor.
- **Test 4** : deux événements qualifiants rapprochés pour la même catégorie → le premier `triggered`, le second `inCooldown`, un seul appel à l'executor.
- **Test 5** : catégorie absente de `SoundEventSettings` → `unknownCategory`, aucun appel à l'executor.
- **Test 6** : événement `isSimulation: true` traité avec les mêmes règles (seuil, activation...) qu'un événement réel, et `SoundEventResult.isSimulation == true` dans le résultat.
- **Test 7** : `stopListening()` puis un événement `source: "microphone"` → `listeningStopped`, aucun appel à l'executor. Un événement `isSimulation: true` reçu après `stopListening()` est traité normalement (décision validée n°4).
- **Test 8** : deux catégories différentes, événements quasi simultanés (sans `await` entre les deux appels à `process()`) → un seul motif net dans `vibrateCalls` (dernier gagne, hérité de `HapticEngine`), pas de mélange incohérent.
- Tests complémentaires : confirmation multi-fenêtres (`requiredConfirmations: 2`, un événement sous le seuil entre les deux remet le compteur à zéro), résultat `hapticFailure` proprement retourné (pas d'exception) si `HapticEngine` rejette la catégorie.

## Exemple de traitement d'un événement

```dart
final processor = SoundEventProcessor(
  hapticEngine: HapticEngine(executor: const MethodChannelVibrationExecutor()),
);

final result = await processor.process(SoundEvent(
  category: 'dog_bark',
  score: 0.91,
  timestamp: DateTime.now(),
  source: 'microphone',
  isSimulation: false,
));

// result.status == SoundEventStatus.unknownCategory si "dog_bark" n'a pas
// été configuré via processor.settings.updateCategory(...) au préalable.
```

## Points d'intégration avec les autres modules

- **Personne 1 (IA)** : doit produire des `SoundEvent` conformes au contrat ci-dessus. Aucun appel de code dans les deux sens au-delà de cette structure de données.
- **Personne 2 (UI)** : consomme `SoundEventResult` pour un éventuel retour visuel, et pourra appeler `SoundEventSettings.updateCategory(...)` depuis un futur écran de réglages.
- **Futurs modules de la personne 3 (Firebase, historique)** : consomment `SoundEventResult` pour l'historique, et pourront persister/synchroniser `SoundEventSettings` sans modifier ce module.
- **Moteur haptique (déjà livré)** : consommé tel quel via `HapticEngine`, sans modification.

## Addendum post-revue : statut `superseded`

La revue finale du module a révélé un cas non prévu par ce document : `HapticEngine.playPattern` termine normalement (sans exception) même quand une demande plus récente l'a silencieusement supplantée ("dernier gagne", voir la spec du moteur haptique). Sans distinction, un événement ainsi supplanté était faussement rapporté `triggered` et démarrait une anti-répétition pour une vibration qui n'avait jamais eu lieu — risque réel pour une application d'accessibilité (l'utilisateur ne ressent rien, et l'événement suivant de la même catégorie peut être bloqué à tort).

Correctif : le pipeline réserve désormais l'horodatage d'anti-répétition *avant* d'appeler `HapticEngine` (pas après), prend un jeton interne au processor au même point, et vérifie ce jeton après l'appel pour distinguer un déclenchement réel d'un déclenchement supplanté. Un statut `SoundEventStatus.superseded` a été ajouté ; en cas d'échec ou de supplantation, la réservation d'anti-répétition est annulée (restaurée à son état précédent) pour ne pas bloquer un vrai événement suivant.
