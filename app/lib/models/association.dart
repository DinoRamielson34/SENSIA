class Association {
  final String name;

  /// Chemins d'assets ; null = illustration et pictogramme par défaut de la maquette.
  final String? bannerAsset;
  final String? logoAsset;

  const Association({required this.name, this.bannerAsset, this.logoAsset});
}
