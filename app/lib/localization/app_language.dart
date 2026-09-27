/// Langue d'affichage de l'app. Le code (`MG`/`FR`) sert d'étiquette
/// courte, indépendante de la langue, pour l'icône de bascule.
enum AppLanguage {
  malagasy('MG'),
  francais('FR');

  final String code;
  const AppLanguage(this.code);
}
