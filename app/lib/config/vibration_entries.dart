import '../models/vibration_entry.dart';

/// Sons affichés par [VibrationsScreen].
// TODO: remplacer par les catégories de [SoundPriorityConfig] ; ce sont les
// libellés de la maquette 90:1650 (« sonnerie », « baby cry », « Text 1 »).
class VibrationEntries {
  VibrationEntries._();

  static const List<VibrationEntry> placeholder = [
    VibrationEntry(id: 'sonnerie', label: 'sonnerie'),
    VibrationEntry(id: 'baby_cry', label: 'baby cry'),
    VibrationEntry(id: 'text_3', label: 'Text 1'),
    VibrationEntry(id: 'text_4', label: 'Text 1'),
    VibrationEntry(id: 'text_5', label: 'Text 1'),
    VibrationEntry(id: 'text_6', label: 'Text 1'),
  ];
}
