# Cache Figma → code (mis à jour par le skill SENSIA-integer)

But : ne pas re-demander à Figma ce qu'on sait déjà. Ajouter une ligne après chaque intégration.

## Pages intégrées
| fileKey | nodeId | Écran Dart | Date | Mode |
|---|---|---|---|---|
| OOhwwFXG19L4SHKUTt9OSs (HACK #2) | 86:367 « Voyant - malvoyant » (360×800) | `app/lib/screens/role_selection_screen.dart` | 2026-09-26 | création |
| OOhwwFXG19L4SHKUTt9OSs (HACK #2) | 90:532 « Probleme de vision » (360×800) | `app/lib/screens/vision_problem_screen.dart` | 2026-09-26 | création |
| OOhwwFXG19L4SHKUTt9OSs (HACK #2) | 90:783 « Ecran principal » (360×800) | `app/lib/screens/listening_screen.dart` | 2026-09-26 | refonte |
| OOhwwFXG19L4SHKUTt9OSs (HACK #2) | 125:220 « Group 2 » (menu home déplié, 320×136) | `app/lib/widgets/home_menu.dart` (utilisé par `listening_screen.dart`) | 2026-09-26 | création |
| OOhwwFXG19L4SHKUTt9OSs (HACK #2) | 90:1900 « autres parametres » (360×800) | `app/lib/screens/settings_screen.dart` | 2026-09-26 | création |
| OOhwwFXG19L4SHKUTt9OSs (HACK #2) | 90:1462 « les associations » (360×800) | `app/lib/screens/associations_screen.dart` | 2026-09-26 | création |
| OOhwwFXG19L4SHKUTt9OSs (HACK #2) | 90:1650 « liste des vibrations » (360×800) | `app/lib/screens/vibrations_screen.dart` | 2026-09-26 | création |
| OOhwwFXG19L4SHKUTt9OSs (HACK #2) | 90:1841 « configuration de la vibration » (360×800) ; contient 125:684 (son long) et 125:685 (son court) ; ouvert par 125:428 (engrenage d'une carte de 90:1650) | `app/lib/screens/vibration_config_screen.dart` | 2026-09-26 | création |
| OOhwwFXG19L4SHKUTt9OSs (HACK #2) | 90:1630 « Ecran » = sauvegarde (360×800) | `app/lib/screens/backup_screen.dart` (+ `app/lib/profile/`) | 2026-09-26 | création |

## Tokens extraits
Extraits de `get_design_context` (pas de `get_variable_defs` : pas de variables Figma), dans `app/lib/theme/app_theme.dart` (`AppColors`) :
- background `#FFF8F0`, primary `#271A42` (bordures, bouton), onPrimary `#F3F3F3`, texte `#0A0A0A`, placeholder image `#D9D9D9`
- Police Nunito (Black 18 titre, Bold 16 libellés, Bold 14 bouton) : **non embarquée** (pas de google_fonts/asset) → fallback système
- Rayons : carte image 8, bouton fingerprint 16, bouton Suivants 8 ; marges 20, gouttière 17

- Écran 90:532 : mêmes couleurs ; options 51 px de haut, rayon 8, espacement 16, texte Nunito Regular 16 ; icône fingerprint de l'option 1 colorée = état sélectionné supposé (fond primary + texte onPrimary)
- Bouton « Suivants » (identique sur 86:367 et 90:532) : widget partagé `app/lib/widgets/next_button.dart`
- Écran 90:783 : barre d'état `#252525` (50 px, rayon 10, icônes 30 grises `#8A8A8A` = éteint), barre d'outils 50×322 bordure noire rayon 8, bouton play 220×220 bordure primary rayon 16 (icône 60), bouton home 60 rond primary ; icônes Material (wifi_off, sync_disabled, warning_amber_rounded, graphic_eq, wifi, sync, bluetooth, play_arrow_outlined, home_outlined)
- Menu 125:220 : 4 pastilles 116×60 rayon 10 fond primary (texte onPrimary 16 + fingerprint 30) aux 4 coins, bouton central 60 rond `#F3F3F3` bordure primary avec icône close ; libellés réels : « Association » ; les 3 autres = placeholder « Settin »
- Écran 90:1900 : 3 blocs (en-tête 22 px bordure noire rayon 8 + 3 lignes 34 px fond `#D9D9D9` rayon 8 avec pastille ronde 30 blanche + libellé), textes Inter 10 noir, espacement 4 (20 entre blocs), bouton home 60 en bas ; libellés = placeholders « Categorie Param N / Parametre N » (`app/lib/config/settings_categories.dart`)
- Écran 90:1462 : 3 cartes (bannière 251×110 rayon 8 bordure primary, fond `#C4C4C4` si pas d'image ; logo 50×50 rayon 8 qui déborde de 25 px sur la bannière ; nom Nunito Regular 16 noir ; bouton message rond 50 `#BCBCBC` icône sms 30), écart 20, bouton home partagé `app/lib/widgets/home_button.dart`
- Navigation du menu home (à jour) : Association → 90:1462, Help → 90:1900, Settings (bas gauche) → 90:1650, 4e pastille (bas droite) renommée « Sauvegarde » → 90:1630
- Écran 90:1650 : grille 2 colonnes de cartes 136×136 (bordure noire rayon 8, écart 48 × 20) : pastille 30 `#D9D9D9` + libellé Nunito 16, puis deux boutons ronds 50 `#BCBCBC` (icônes waves / settings 30) ; libellés placeholders (`app/lib/config/vibration_entries.dart`)
- Écran 90:1841 : panneau blanc 320×312 bordure noire rayon 8 (= motif construit) ; boutons son long (pastille 46×12) / son court (point 12) 88×50 rayon 10, écart 48 ; puis 3 boutons 48×48 rayon 8 écart 20 : effacer (replay), essayer (play), valider (check) ; bouton home partagé
- Écran 90:1630 : avatar rond 140 `#D9D9D9` bordure noire (placeholder), « ID: <uid Firebase> » Inter 10, deux boutons 138/136×136 bordure noire rayon 8 (Sauvegarder mes donnees + favorite_border ; Restaurer les donnees + download, texte 10), bouton home partagé
- Firebase : `main()` initialise Firebase ; profil = doc Firestore `users/{uid}/profile/main` (règle ajoutée dans `app/firestore.rules`, à déployer)

## Assets
- `app/assets/images/role_accompagnateur.png` (Figma 1afac), `role_client.png` (Figma 4ab7e) : téléchargés, déclarés dans pubspec (`assets/images/`)
- `app/assets/images/association_banner_fjkm.png` (Figma 5b416), `association_logo_fjkm.png` (Figma 00828)
- Icônes fingerprint / skip-next : remplacées par `Icons.fingerprint` / `Icons.skip_next_outlined`
