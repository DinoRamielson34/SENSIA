enum ColorVisionType {
  protanopie('Protanopie'),
  deuteranopie('Deutéranopie'),
  tritanopie('Tritanopie'),
  achromatopsie('Achromatopsie'),
  daltonisme('Daltonisme');

  final String label;

  const ColorVisionType(this.label);
}
