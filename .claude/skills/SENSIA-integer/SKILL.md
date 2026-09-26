---
name: SENSIA-integer
description: Intègre une maquette Figma dans l'app Flutter SENSIA (dossier app/). L'utilisateur donne un lien Figma (figma.com/design/... ou node-id) ; le skill refond la page si elle existe déjà dans app/lib, sinon crée la page ET sa logique (état, service, modèle) en suivant la structure du code existant, tout en limitant au strict minimum les appels au MCP Figma. À utiliser dès que l'utilisateur colle un lien Figma, dit « intègre / refonds / crée cette page / cet écran », « fais la maquette », « mets à jour l'UI depuis Figma », même sans citer le nom du skill.
---

# SENSIA-integer : Figma → Flutter, sans gaspiller le MCP

Entrée : un lien Figma (+ optionnellement le nom de la page). Sortie : un écran Flutter intégré au code existant, refondu ou créé, avec sa logique si elle n'existe pas.

Deux contraintes structurent tout le skill :
1. **Économiser le MCP Figma** : chaque appel coûte des tokens et du quota. Un appel bien ciblé vaut mieux que cinq exploratoires.
2. **Suivre le code existant** : l'app a déjà une architecture ; on s'y greffe, on n'en invente pas une deuxième.

Les outils Figma sont différés : charge-les d'un coup avec ToolSearch (`select:mcp__claude_ai_Figma__get_metadata,mcp__claude_ai_Figma__get_design_context,mcp__claude_ai_Figma__get_screenshot,mcp__claude_ai_Figma__get_variable_defs`) avant le premier appel.

## Étape 0 : lire le code AVANT Figma (0 appel MCP)

Le code dit ce qu'on va chercher dans Figma ; le faire d'abord évite des appels inutiles.

1. Lis `references/architecture.md` (conventions SENSIA relevées dans le repo).
2. Lis `references/figma-map.md` : table lien/nodeId Figma → fichier Dart, et tokens déjà extraits. **Si le nodeId y figure avec un contenu à jour, ne réappelle pas Figma pour les tokens ; refais seulement les appels sur ce qui a changé.**
3. Déduis du nom de la page / du lien si l'écran existe : `Glob app/lib/screens/*` et `Grep` sur le nom (ex. `class XxxScreen`). Note aussi les routes/navigation dans `app/lib/main.dart`.
4. Décide du mode :
   - **REFONTE** : l'écran existe → on garde sa logique (état, pipeline, callbacks, paramètres du constructeur) et on ne change que la couche visuelle.
   - **CRÉATION** : il n'existe pas → on crée écran + logique nécessaire.
   Annonce le mode en une ligne à l'utilisateur ; si c'est ambigu (nom proche d'un écran existant), demande.

## Étape 1 : budget d'appels Figma

Parse le lien : `fileKey` = segment après `/design/`, `nodeId` = paramètre `node-id` (`12-34` devient `12:34`). Pour une branche (`/branch/<key>/`), utilise la clé de branche.

Ordre imposé, du moins cher au plus cher. Arrête-toi dès que tu as assez :

| # | Appel | Quand | Pourquoi |
|---|-------|-------|----------|
| 1 | `get_metadata(nodeId)` | toujours, 1 fois | arbre léger (ids, noms, tailles) : sert à découper l'écran en sections et à repérer les composants répétés |
| 2 | `get_design_context(nodeId)` | 1 fois par section feuille, **pas sur la page entière** si elle est grande | renvoie code + styles + assets ; sur un écran complet la réponse est énorme |
| 3 | `get_variable_defs(nodeId)` | seulement si `references/figma-map.md` n'a pas déjà les tokens | couleurs/typos/espacements ; à mettre en cache ensuite |
| 4 | `get_screenshot(nodeId)` | 1 fois, sur la racine, pour contrôler le rendu final | jamais par section |
| 5 | `download_assets` | seulement pour icônes/images absentes de `Icons.*` | préfère les icônes Material quand la ressemblance est fidèle |

Règles d'économie :
- **Jamais deux fois le même nodeId** dans une session : garde le résultat en tête, ne redemande pas.
- **Composants répétés** (cartes de liste, boutons) : un seul appel sur une instance, puis un widget réutilisable.
- **Pas d'appel exploratoire** (`search_design_system`, `get_libraries`, `whoami`, Code Connect) sauf demande explicite.
- **Un seul aller-retour de correction** : si le rendu diffère, corrige depuis les données déjà récupérées avant de redemander quoi que ce soit.
- Si un appel échoue (accès, quota), dis-le et propose de continuer avec ce qu'on a au lieu de réessayer en boucle.
- Le code que renvoie `get_design_context` est généralement du React/HTML : c'est une **référence de structure et de valeurs**, jamais à copier. Traduis en widgets Flutter.

## Étape 2 : traduire en Flutter en suivant la structure

Respecte `references/architecture.md`. Points clés :

- **UI** dans `app/lib/screens/<nom>_screen.dart`. Widgets réutilisables (≥ 2 usages) dans `app/lib/widgets/` (dossier à créer au premier besoin).
- **Couleurs / typos / espacements** : utilise `Theme.of(context).colorScheme` / `textTheme` quand une valeur Figma correspond au thème. Les valeurs propres à la maquette vont dans **un seul** fichier `app/lib/theme/app_theme.dart` (à créer au premier besoin, branché dans `MaterialApp.theme` de `main.dart`), pas en `Color(0x…)` éparpillés dans les écrans.
- **Logique** : `ChangeNotifier` + `ListenableBuilder` (pattern de `ListeningScreen`), dépendances injectées par le constructeur (paramètre optionnel pour les tests), `dispose` correct.
- **Modèles** dans `app/lib/models/` (ou `<feature>/models/`), **services** dans `app/lib/services/`, **constantes/config** dans `app/lib/config/`.
- Commentaires et textes UI en **français**, comme le reste du code. Commentaires rares, uniquement pour le « pourquoi ».
- Pas de nouvelle dépendance dans `pubspec.yaml` sans la signaler à l'utilisateur. Nouveaux assets déclarés dans `pubspec.yaml`.
- Ne casse jamais l'existant : `flutter_test` et les `*_debug_main.dart` doivent continuer de compiler.

### Mode REFONTE
1. Lis l'écran entier et ses dépendances directes.
2. Liste ce qui est **logique** (à conserver telle quelle) vs **présentation** (à remplacer).
3. Réécris le `build` et les helpers visuels ; extrais en widgets ce qui se répète. Garde noms publics, signature du constructeur et comportements.
4. Si la maquette exige une donnée que l'écran n'a pas, ajoute-la dans la logique existante (le plus petit changement possible) et signale-le.

### Mode CRÉATION
1. Crée `<nom>_screen.dart`.
2. Crée la logique **seulement ce que la maquette implique** : un `ChangeNotifier` (dans `services/` s'il orchestre des services, sinon un contrôleur près de l'écran), les modèles de données, la config. Branche sur les services existants quand ils couvrent le besoin (audio, haptique, historique Firestore) plutôt que d'en réécrire.
3. Données pas encore disponibles : injecte une source factice derrière la même interface pour que l'écran fonctionne, et marque-la clairement `// TODO`.
4. Branche la navigation (`main.dart` ou `Navigator.push` depuis l'écran parent le plus logique). Demande à l'utilisateur si le point d'entrée n'est pas évident.

## Étape 3 : vérifier

1. `cd app && dart format <fichiers touchés>` puis `flutter analyze` sur ces fichiers : zéro nouvelle erreur/avertissement.
2. Pour un écran nouveau ou une logique non triviale : un widget test minimal dans `app/test/` (rendu sans exception + un comportement clé). Lance `flutter test <fichier>`.
3. Si possible, compare avec l'unique `get_screenshot` de l'étape 1 (marges, hiérarchie, couleurs, ordre des éléments). Ne lance pas l'appli pour rien si le test widget suffit.
4. Ne prétends pas « fidèle à la maquette » sans avoir comparé ; dis ce qui est vérifié et ce qui ne l'est pas.

## Étape 4 : mémoire et rapport

1. Mets à jour `references/figma-map.md` : ligne `nodeId | écran Dart | date | tokens extraits`, plus les tokens nouveaux. C'est ce qui permet au prochain appel de ne pas refaire les mêmes requêtes Figma.
2. Ne fais **aucun `git add` / `git commit`** : l'utilisateur gère git lui-même.
3. Rapport final court : mode (refonte/création), fichiers créés/modifiés, nombre d'appels Figma utilisés et lesquels, ce qui a été vérifié, écarts ou hypothèses restantes.
