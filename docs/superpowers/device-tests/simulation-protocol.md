# Protocole de test IZAHAY sur téléphone physique

Ce document ne contient aucun résultat : les champs sont à remplir après
exécution réelle sur un appareil. Aucun taux de fiabilité ni latence n'est
annoncé tant qu'il n'a pas été mesuré.

## Points à vérifier

1. **Présence du moteur de vibration** : `HapticEngine.isDeviceCompatible()`
   retourne `true` sur l'appareil de test (voir `lib/haptics_debug_main.dart`).
2. **Exécution de deux motifs distincts** : déclencher "sonnette" puis
   "aboiement" depuis `lib/simulation_debug_main.dart` ou
   `lib/haptics_debug_main.dart`, confirmer que les deux vibrations sont
   perceptiblement différentes.
3. **Arrêt d'une vibration** : déclencher un motif long, appeler `stop()`
   en cours de route, confirmer l'arrêt immédiat.
4. **Fonctionnement hors ligne** : couper les données/Wi-Fi du téléphone,
   déclencher un événement simulé depuis `lib/simulation_debug_main.dart` —
   la vibration doit se produire normalement (l'historique se
   synchronisera plus tard, voir le module Firebase).
5. **Persistance de l'historique après redémarrage** : enregistrer un
   événement, fermer complètement l'app, la rouvrir, vérifier que
   l'historique est toujours présent.
6. **Réception de deux événements sonores différents (modèle IA
   disponible)** : à exécuter une fois le module de reconnaissance
   sonore livré par la personne 1 — hors de portée tant qu'il n'existe
   pas.
7. **Différence événement simulé / événement réellement reconnu** :
   vérifier que `SoundEventResult.isSimulation` (visible dans
   l'historique) distingue bien les deux.

## Tableau de consignation par essai

À dupliquer pour chaque essai réel (viser au moins 10 essais par
catégorie quand le temps le permet, une fois les catégories sonores
disponibles) :

| Champ | Valeur |
|---|---|
| Catégorie attendue | |
| Catégorie reconnue | |
| Score | |
| Téléphone utilisé | |
| Source audio | |
| Distance approximative | |
| Bruit ambiant | |
| Résultat | |
| Délai son → vibration (si mesurable) | |
