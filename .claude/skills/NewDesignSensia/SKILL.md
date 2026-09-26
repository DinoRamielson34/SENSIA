---
name: NewDesignSensia
description: Compare une page Flutter existante de l'app SENSIA (app/lib) avec sa nouvelle maquette Figma (via le MCP Figma OU une capture PNG) puis modifie l'UI pour qu'elle soit identique à la maquette. Paramètres - nom de la page, source du design (mcp figma + lien, ou chemin d'un png). À utiliser dès que l'utilisateur dit que le design a changé, « mets la page X comme dans le figma », « rends-la pareille que la maquette », « compare avec le png », « NewDesignSensia », même sans citer le nom du skill.
---

# NewDesignSensia : aligner une page existante sur le nouveau design

Entrée :
- **page** : nom de la page/écran (ex. `listening`, `profile`, `history`).
- **source** : `figma` (+ lien `figma.com/design/...?node-id=...`) ou `png` (+ chemin du fichier image).

Si un paramètre manque, demande-le en une seule question (page ? source figma ou png ? lien/chemin ?). Ne devine pas la page si plusieurs écrans correspondent.

Sortie : la page Flutter modifiée pour ressembler à la maquette, sans casser sa logique, et un court rapport des écarts corrigés.

Différence avec `SENSIA-integer` : ici la page existe déjà, on ne crée pas de logique. Le travail est **diff visuel puis correction**. Si la page n'existe pas, dis-le et propose `SENSIA-integer`.

## Étape 1 : trouver la page et lire le code (0 appel Figma)

1. `Glob app/lib/**/*` + `Grep` sur le nom pour localiser l'écran (`class XxxScreen`) et ses widgets/thèmes associés.
2. Lis l'écran en entier, plus `app/lib/theme/` et `app/lib/widgets/` s'ils existent. Note ce qui est **logique** (état, callbacks, constructeur) : il ne doit pas bouger.
3. Lis `.claude/skills/SENSIA-integer/references/architecture.md` et `figma-map.md` s'ils existent : conventions et tokens déjà extraits (évite de redemander à Figma).

## Étape 2 : récupérer la référence visuelle

### Source = Figma
Charge les outils d'un coup : ToolSearch `select:mcp__claude_ai_Figma__get_metadata,mcp__claude_ai_Figma__get_design_context,mcp__claude_ai_Figma__get_screenshot,mcp__claude_ai_Figma__get_variable_defs`.

`fileKey` = segment après `/design/`, `nodeId` = `node-id` (`12-34` devient `12:34`). Budget, du moins cher au plus cher, arrête-toi dès que tu as assez :
1. `get_metadata(nodeId)` : structure, tailles, sections.
2. `get_screenshot(nodeId)` sur la racine : la vérité visuelle pour la comparaison.
3. `get_design_context` par section (pas sur une grande page entière) : valeurs exactes (couleurs, typos, paddings, radius). Le code renvoyé est du React/HTML, sert de référence de valeurs, jamais à copier.
4. `get_variable_defs` seulement si les tokens ne sont pas déjà connus.
Jamais deux fois le même nodeId ; pas d'appel exploratoire ; si un appel échoue, dis-le et propose de continuer avec le PNG.

### Source = PNG
Lis l'image avec Read. Estime les valeurs (espacements, tailles, couleurs hex) à l'œil et **signale qu'elles sont approximatives** : un PNG ne donne pas les valeurs exactes. Si l'utilisateur a aussi le lien Figma, propose de l'utiliser pour les valeurs précises.

## Étape 3 : comparer (tableau d'écarts)

Compare la référence avec le code actuel (et, si utile, une capture de l'écran actuel fournie par l'utilisateur ; ne lance pas l'appli pour rien). Produis un tableau court, priorisé, avant de coder :

| Zone | Actuel | Maquette | Action |
|------|--------|----------|--------|

Vérifie : structure/ordre des éléments, éléments manquants ou en trop, espacements et paddings, dimensions, alignements, couleurs, typographies (taille, graisse, famille), icônes/images, bordures/rayons, ombres, états (actif, désactivé), textes.

Montre le tableau à l'utilisateur en quelques lignes, puis enchaîne sur la correction sans attendre sauf si un écart change le comportement (ex. un bouton en plus qui demande une nouvelle action).

## Étape 4 : corriger pour que ce soit identique

- Modifie **uniquement la couche visuelle** : `build`, helpers visuels, thème. Garde noms publics, signature du constructeur, callbacks, état.
- Valeurs de la maquette dans un seul fichier de thème (`app/lib/theme/app_theme.dart`, à créer si besoin, branché dans `MaterialApp.theme`), pas de `Color(0x…)` éparpillés. Réutilise `Theme.of(context)` quand la valeur correspond au thème.
- Extrais en widget (`app/lib/widgets/`) ce qui se répète ≥ 2 fois.
- Icônes : `Icons.*` si fidèle, sinon `download_assets` (Figma) et déclaration dans `pubspec.yaml`. Signale toute nouvelle dépendance avant de l'ajouter.
- Si la maquette exige une donnée absente, ajoute le minimum dans la logique existante et signale-le.
- Textes UI et commentaires en français, commentaires rares (le « pourquoi »).

## Étape 5 : vérifier

Tout tourne sous Docker (pas de Flutter sur l'hôte) : utilise la même commande docker que celle des autres skills/README du repo pour `dart format` et `flutter analyze` sur les fichiers touchés (zéro nouvelle erreur), et `flutter test` sur les tests de la page si présents. Ne les lance pas en local.

Re-compare ensuite le code final avec la référence, zone par zone. Ne dis « identique » que pour ce que tu as réellement comparé ; liste ce qui reste approximatif (surtout en mode PNG) ou non vérifié visuellement (rendu réel non lancé).

## Étape 6 : rapport

Court : page modifiée, source utilisée, appels Figma faits, écarts corrigés, écarts restants/approximations, fichiers touchés. **Aucun `git add`/`git commit`** : l'utilisateur gère git lui-même.
