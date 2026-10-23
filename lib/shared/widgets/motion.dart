import 'package:material_ui/material_ui.dart';

/// M3 motion helpers (#85). Each one shows its child at rest right away when
/// the user turns animations off.
abstract final class Motion {
  static const short = Duration(milliseconds: 200);
  static const medium = Duration(milliseconds: 300);
  static const long = Duration(milliseconds: 600);

  static Duration of(BuildContext context, Duration duration) =>
      MediaQuery.disableAnimationsOf(context) ? Duration.zero : duration;
}

/// Fades and slightly scales [child] in whenever [switchKey] changes, the
/// incoming half of the M3 fade-through. Used between top-level tabs, whose
/// pages stay alive in an `IndexedStack` so the outgoing one simply hides.
class FadeThrough extends StatefulWidget {
  const FadeThrough({super.key, required this.switchKey, required this.child});

  final Object switchKey;
  final Widget child;

  @override
  State<FadeThrough> createState() => _FadeThroughState();
}

class _FadeThroughState extends State<FadeThrough>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: Motion.medium,
    value: 1,
  );
  late final _curve = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
  );

  @override
  void didUpdateWidget(FadeThrough oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.switchKey == oldWidget.switchKey) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
    } else {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _curve.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _curve,
      child: ScaleTransition(
        scale: Tween(begin: 0.96, end: 1.0).animate(_curve),
        child: widget.child,
      ),
    );
  }
}

/// Horizontal M3 shared-axis transition between siblings such as form
/// steps. [forward] picks the direction: new content enters from the right
/// when moving forward and from the left when going back.
class SharedAxisSwitcher extends StatelessWidget {
  const SharedAxisSwitcher({
    super.key,
    required this.forward,
    required this.child,
  });

  final bool forward;

  /// Give it a key that changes with the content.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: Motion.of(context, Motion.medium),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      layoutBuilder: (current, previous) =>
          Stack(children: [...previous, ?current]),
      transitionBuilder: (child, animation) {
        // The outgoing child runs its animation in reverse, so it leaves
        // on the side opposite to where the incoming child enters.
        final incoming = child.key == this.child.key;
        final from = (forward == incoming) ? 0.08 : -0.08;
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween(
              begin: Offset(from, 0),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

/// Fades and lifts [child] in once, when it is first built, delayed by its
/// [index] so a list appears one item after another.
class StaggeredEntrance extends StatefulWidget {
  const StaggeredEntrance({
    super.key,
    required this.index,
    required this.child,
  });

  final int index;
  final Widget child;

  /// Later items start together so a long list does not keep the user
  /// waiting.
  static const maxStaggered = 8;

  @override
  State<StaggeredEntrance> createState() => _StaggeredEntranceState();
}

class _StaggeredEntranceState extends State<StaggeredEntrance>
    with SingleTickerProviderStateMixin {
  static const _step = Duration(milliseconds: 60);

  late final AnimationController _controller;
  late final CurvedAnimation _curve;

  @override
  void initState() {
    super.initState();
    final delay = _step * widget.index.clamp(0, StaggeredEntrance.maxStaggered);
    final total = delay + Motion.medium;
    _controller = AnimationController(vsync: this, duration: total);
    _curve = CurvedAnimation(
      parent: _controller,
      curve: Interval(
        delay.inMicroseconds / total.inMicroseconds,
        1,
        curve: Curves.easeOutCubic,
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller.isAnimating || _controller.isCompleted) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _curve.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _curve,
      child: SlideTransition(
        position: Tween(
          begin: const Offset(0, 0.15),
          end: Offset.zero,
        ).animate(_curve),
        child: widget.child,
      ),
    );
  }
}
