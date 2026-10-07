import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

/// Poses of the elephant mascot in `assets/mascot/` (docs/MASCOT.md).
enum MascotPose {
  wave,
  calendar,
  budget,
  map,
  celebrate;

  String get asset => 'assets/mascot/$name.webp';
}

/// The elephant mascot, floating gently and cross-fading between poses.
///
/// Purely decorative: screen readers skip it and it stands still when the
/// user turns animations off. It floats for under five seconds after it
/// appears or changes pose, then rests (WCAG 2.2.2), which also lets
/// `pumpAndSettle` finish in tests. It never grows past [size] or the space
/// it is given, so large text keeps its room.
class MascotView extends StatefulWidget {
  const MascotView({super.key, required this.pose, this.size = 160});

  final MascotPose pose;

  /// Largest width and height in logical pixels.
  final double size;

  @override
  State<MascotView> createState() => _MascotViewState();
}

class _MascotViewState extends State<MascotView>
    with SingleTickerProviderStateMixin {
  /// One rise or one fall; [_floatTimes] of them make up the idle motion.
  late final _float = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );
  static const _floatTimes = 4;

  bool get _still => MediaQuery.disableAnimationsOf(context);

  void _startFloating() {
    if (_still) {
      _float
        ..stop()
        ..value = 0;
    } else {
      _float.repeat(reverse: true, count: _floatTimes);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_still || !_float.isAnimating && _float.value == 0) _startFloating();
  }

  @override
  void didUpdateWidget(MascotView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pose != widget.pose) _startFloating();
  }

  @override
  void dispose() {
    _float.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final still = _still;
    return ExcludeSemantics(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final side = math.min(
            widget.size,
            math.min(constraints.maxWidth, constraints.maxHeight),
          );
          final cacheWidth = (side * MediaQuery.devicePixelRatioOf(context))
              .round();
          return SizedBox.square(
            dimension: side,
            child: AnimatedBuilder(
              animation: _float,
              builder: (context, child) => Transform.translate(
                offset: Offset(
                  0,
                  -side * 0.03 * Curves.easeInOut.transform(_float.value),
                ),
                child: child,
              ),
              child: AnimatedSwitcher(
                duration: still
                    ? Duration.zero
                    : const Duration(milliseconds: 350),
                switchInCurve: Curves.easeOutBack,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(
                    scale: Tween(begin: 0.85, end: 1.0).animate(animation),
                    child: child,
                  ),
                ),
                child: Image.asset(
                  widget.pose.asset,
                  key: ValueKey(widget.pose),
                  width: side,
                  height: side,
                  cacheWidth: cacheWidth,
                  fit: BoxFit.contain,
                  gaplessPlayback: true,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// The mascot's face in a circle, used as the AI assistant's picture.
class MascotAvatar extends StatelessWidget {
  const MascotAvatar({super.key, this.radius = 20});

  final double radius;

  static const asset = 'assets/mascot/avatar.webp';

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: CircleAvatar(
        radius: radius,
        backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
        foregroundImage: ResizeImage(
          const AssetImage(asset),
          width: (radius * 2 * MediaQuery.devicePixelRatioOf(context)).round(),
        ),
      ),
    );
  }
}
