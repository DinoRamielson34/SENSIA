# Cache Figma → code (mis à jour par le skill SENSIA-integer)

But : ne pas re-demander à Figma ce qu'on sait déjà. Ajouter une ligne après chaque intégration.

## Pages intégrées
| fileKey | nodeId | Écran Dart | Date | Mode |
|---|---|---|---|---|
| OOhwwFXG19L4SHKUTt9OSs (HACK #2) | 86:367 « Voyant - malvoyant » (360×800) | `app/lib/screens/role_selection_screen.dart` | 2026-09-26 | création |

## Tokens extraits
Extraits de `get_design_context` (pas de `get_variable_defs` : pas de variables Figma), dans `app/lib/theme/app_theme.dart` (`AppColors`) :
- background `#FFF8F0`, primary `#271A42` (bordures, bouton), onPrimary `#F3F3F3`, texte `#0A0A0A`, placeholder image `#D9D9D9`
- Police Nunito (Black 18 titre, Bold 16 libellés, Bold 14 bouton) : **non embarquée** (pas de google_fonts/asset) → fallback système
- Rayons : carte image 8, bouton fingerprint 16, bouton Suivants 8 ; marges 20, gouttière 17

## Assets
- `app/assets/images/role_accompagnateur.png` (Figma 1afac), `role_client.png` (Figma 4ab7e) : téléchargés, déclarés dans pubspec (`assets/images/`)
- Icônes fingerprint / skip-next : remplacées par `Icons.fingerprint` / `Icons.skip_next_outlined`
