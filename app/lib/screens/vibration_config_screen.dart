import 'package:flutter/material.dart';

import '../haptics/haptic_engine.dart';
import '../haptics/haptic_exceptions.dart';
import '../haptics/models/vibration_pattern.dart';
import '../haptics/vibration_executor.dart';
import '../models/vibration_entry.dart';
import '../models/vibration_segment.dart';
import '../theme/app_theme.dart';
import '../widgets/home_button.dart';

/// Construit un motif en enchaînant des segments longs et courts.
class VibrationConfigController extends ChangeNotifier {
  // Mêmes durées de référence que HapticPatternConfig (long / court / pause).
  static const longDuration = Duration(milliseconds: 500);
  static const shortDuration = Duration(milliseconds: 150);
  static const gap = Duration(milliseconds: 150);

  final List<VibrationSegment> _segments;

  VibrationConfigController([List<VibrationSegment> initial = const []])
    : _segments = List.of(initial);

  List<VibrationSegment> get segments => List.unmodifiable(_segments);

  bool get isEmpty => _segments.isEmpty;

  void add(VibrationSegment segment) {
    _segments.add(segment);
    notifyListeners();
  }

  void reset() {
    if (_segments.isEmpty) return;
    _segments.clear();
    notifyListeners();
  }

  /// Motif correspondant aux segments saisis, ou null s'il n'y en a aucun.
  VibrationPattern? toPattern(String id) {
    if (_segments.isEmpty) return null;
    return VibrationPattern(
      id: id,
      pulses: [
        for (var i = 0; i < _segments.length; i++)
          VibrationPulse(
            vibrate: _segments[i] == VibrationSegment.long
                ? longDuration
                : shortDuration,
            pauseAfter: i == _segments.length - 1 ? Duration.zero : gap,
          ),
      ],
    );
  }
}

class VibrationConfigScreen extends StatefulWidget {
  final VibrationEntry entry;
  final VibrationConfigController? controller;
  final HapticEngine? hapticEngine;

  /// Segments à afficher au départ (par exemple ceux d'une sauvegarde).
  final List<VibrationSegment> initialSegments;

  /// Appelé au tap sur « valider » avec les segments saisis ; l'écran se ferme ensuite.
  // TODO: enregistrer aussi le motif dans le moteur du pipeline
  // (HapticEngine.registerPattern) ; l'écran n'y a pas accès pour l'instant.
  final void Function(VibrationEntry entry, List<VibrationSegment> segments)?
  onValidate;

  /// Appelé au tap sur « home » ; par défaut, revient en arrière.
  final VoidCallback? onHome;

  const VibrationConfigScreen({
    super.key,
    required this.entry,
    this.controller,
    this.hapticEngine,
    this.initialSegments = const [],
    this.onValidate,
    this.onHome,
  });

  @override
  State<VibrationConfigScreen> createState() => _VibrationConfigScreenState();
}

class _VibrationConfigScreenState extends State<VibrationConfigScreen> {
  late final VibrationConfigController _controller;
  late final HapticEngine _hapticEngine;

  @override
  void initState() {
    super.initState();
    _controller =
        widget.controller ?? VibrationConfigController(widget.initialSegments);
    _hapticEngine =
        widget.hapticEngine ??
        HapticEngine(executor: const MethodChannelVibrationExecutor());
  }

  @override
  void dispose() {
    if (widget.controller == null) _controller.dispose();
    super.dispose();
  }

  Future<void> _play() async {
    final pattern = _controller.toPattern(widget.entry.id);
    if (pattern == null) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _hapticEngine.playPattern(pattern);
    } on HapticUnsupportedException {
      messenger.showSnackBar(
        const SnackBar(content: Text('Cet appareil ne peut pas vibrer.')),
      );
    } on InvalidVibrationPatternException {
      messenger.showSnackBar(
        const SnackBar(content: Text('Motif de vibration invalide.')),
      );
    }
  }

  void _validate() {
    final pattern = _controller.toPattern(widget.entry.id);
    if (pattern == null) return;
    widget.onValidate?.call(widget.entry, _controller.segments);
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _controller,
          builder: (context, _) {
            final empty = _controller.isEmpty;
            return Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 96, 20, 16),
                    child: Column(
                      children: [
                        _PatternPanel(segments: _controller.segments),
                        const SizedBox(height: 18),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _SegmentButton(
                              label: 'Ajouter un son long',
                              segment: VibrationSegment.long,
                              onTap: () =>
                                  _controller.add(VibrationSegment.long),
                            ),
                            const SizedBox(width: 48),
                            _SegmentButton(
                              label: 'Ajouter un son court',
                              segment: VibrationSegment.short,
                              onTap: () =>
                                  _controller.add(VibrationSegment.short),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _ActionButton(
                              icon: Icons.replay,
                              label: 'Effacer le motif',
                              onTap: empty ? null : _controller.reset,
                            ),
                            const SizedBox(width: 20),
                            _ActionButton(
                              icon: Icons.play_arrow_outlined,
                              label: 'Essayer la vibration',
                              onTap: empty ? null : _play,
                            ),
                            const SizedBox(width: 20),
                            _ActionButton(
                              icon: Icons.check,
                              label: 'Valider',
                              onTap: empty ? null : _validate,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                HomeButton(
                  onPressed:
                      widget.onHome ?? () => Navigator.of(context).maybePop(),
                ),
                const SizedBox(height: 40),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Zone blanche : le motif construit, segment après segment.
class _PatternPanel extends StatelessWidget {
  final List<VibrationSegment> segments;

  const _PatternPanel({required this.segments});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 312,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black),
        borderRadius: BorderRadius.circular(8),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final segment in segments) SegmentMark(segment: segment),
          ],
        ),
      ),
    );
  }
}

/// Pastille allongée (long) ou point (court), comme dans la maquette.
class SegmentMark extends StatelessWidget {
  final VibrationSegment segment;

  const SegmentMark({super.key, required this.segment});

  @override
  Widget build(BuildContext context) {
    final long = segment == VibrationSegment.long;
    return Container(
      width: long ? 46 : 12,
      height: 12,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black),
        borderRadius: BorderRadius.circular(200),
      ),
    );
  }
}

class _SegmentButton extends StatelessWidget {
  final String label;
  final VibrationSegment segment;
  final VoidCallback onTap;

  const _SegmentButton({
    required this.label,
    required this.segment,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 88,
          height: 50,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.black),
            borderRadius: BorderRadius.circular(10),
          ),
          child: SegmentMark(segment: segment),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            border: Border.all(
              color: onTap == null ? AppColors.disabled : Colors.black,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 30,
            color: onTap == null ? AppColors.disabled : Colors.black,
          ),
        ),
      ),
    );
  }
}
