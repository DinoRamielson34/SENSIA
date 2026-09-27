import '../localization/app_strings.dart';

enum ColorVisionType {
  protanopie,
  deuteranopie,
  tritanopie,
  achromatopsie,
  daltonisme;

  String label(AppStrings strings) => switch (this) {
    ColorVisionType.protanopie => strings.visionProtanopie,
    ColorVisionType.deuteranopie => strings.visionDeuteranopie,
    ColorVisionType.tritanopie => strings.visionTritanopie,
    ColorVisionType.achromatopsie => strings.visionAchromatopsie,
    ColorVisionType.daltonisme => strings.visionDaltonisme,
  };
}
