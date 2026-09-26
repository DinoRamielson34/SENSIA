class Association {
  final String name;

  /// Chemins d'assets ; null = fond gris (comme la première carte de la maquette).
  final String? bannerAsset;
  final String? logoAsset;

  const Association({required this.name, this.bannerAsset, this.logoAsset});
}
