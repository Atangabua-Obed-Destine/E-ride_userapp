import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';

/// The "finding your driver" animation shown in the bottom sheet while a
/// request is out to nearby drivers.
///
/// Replaces three bare LinearProgressIndicators and a static PNG. It is fed
/// by the same RideController state the old widget used (stateCount and the
/// three count values), so the escalation logic is untouched: this is purely
/// the presentation.
///
///   stage 0..2  searching: sweep rotates, pulses expand, one more nearby
///               driver chip appears each stage
///   stage 3     no driver found: sweep and pulses stop, chips dim, the
///               caller shows its keep-searching / raise-fare actions
class DriverSearchRadar extends StatefulWidget {
  final int stage;
  final double first;
  final double second;
  final double third;
  final double size;

  const DriverSearchRadar({
    super.key,
    required this.stage,
    required this.first,
    required this.second,
    required this.third,
    this.size = 168,
  });

  @override
  State<DriverSearchRadar> createState() => _DriverSearchRadarState();
}

class _DriverSearchRadarState extends State<DriverSearchRadar> with SingleTickerProviderStateMixin {
  late final AnimationController _spin;
  bool _reduceMotion = false;

  bool get _searching => widget.stage < 3;

  @override
  void initState() {
    super.initState();
    _spin = AnimationController(vsync: this, duration: const Duration(milliseconds: 2800));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    _syncMotion();
  }

  @override
  void didUpdateWidget(covariant DriverSearchRadar old) {
    super.didUpdateWidget(old);
    if (old.stage != widget.stage) _syncMotion();
  }

  void _syncMotion() {
    if (_reduceMotion || !_searching) {
      _spin.stop();
      if (_reduceMotion) _spin.value = 0.35;
    } else if (!_spin.isAnimating) {
      _spin.repeat();
    }
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color accent = Theme.of(context).primaryColor;
    final Duration d = _reduceMotion ? Duration.zero : const Duration(milliseconds: 420);
    // One more driver appears per stage, up to three.
    final int visible = math.min(widget.stage + 1, 3);

    return Column(mainAxisSize: MainAxisSize.min, children: [
      SizedBox(
        width: widget.size,
        height: widget.size,
        child: Stack(alignment: Alignment.center, children: [
          CustomPaint(
            size: Size.square(widget.size),
            painter: _RadarPainter(
              animation: _spin,
              accent: accent,
              ring: Theme.of(context).hintColor,
              searching: _searching,
            ),
          ),

          for (int i = 0; i < 3; i++)
            Align(
              alignment: _chipAlignment[i],
              child: AnimatedScale(
                scale: i < visible ? 1 : 0,
                duration: d,
                curve: Curves.easeOutBack,
                child: AnimatedOpacity(
                  opacity: _searching ? 1 : 0.35,
                  duration: d,
                  child: _DriverChip(accent: accent, highlighted: i == visible - 1 && _searching),
                ),
              ),
            ),
        ]),
      ),
      const SizedBox(height: Dimensions.paddingSizeDefault),

      _StageBar(values: [widget.first, widget.second, widget.third], accent: accent, duration: d),
    ]);
  }

  static const List<Alignment> _chipAlignment = [
    Alignment(0.62, -0.58),
    Alignment(-0.72, 0.18),
    Alignment(0.38, 0.74),
  ];
}

class _DriverChip extends StatelessWidget {
  final Color accent;
  final bool highlighted;
  const _DriverChip({required this.accent, required this.highlighted});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: highlighted ? accent : Colors.white,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 8, offset: const Offset(0, 3)),
        ],
      ),
      child: Icon(
        Icons.directions_car_rounded,
        size: 15,
        color: highlighted ? Colors.white : const Color(0xFF3A3A42),
      ),
    );
  }
}

/// The three search stages, as one segmented bar instead of three loose
/// progress indicators. Fed by the controller's first/second/third counts.
class _StageBar extends StatelessWidget {
  final List<double> values;
  final Color accent;
  final Duration duration;
  const _StageBar({required this.values, required this.accent, required this.duration});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      for (int i = 0; i < values.length; i++) ...[
        if (i > 0) const SizedBox(width: 6),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 5,
              child: Stack(children: [
                Container(color: accent.withValues(alpha: 0.14)),
                AnimatedFractionallySizedBox(
                  duration: duration,
                  curve: Curves.easeOut,
                  alignment: Alignment.centerLeft,
                  widthFactor: values[i].clamp(0.0, 1.0),
                  child: Container(color: accent),
                ),
              ]),
            ),
          ),
        ),
      ],
    ]);
  }
}

class _RadarPainter extends CustomPainter {
  final Animation<double> animation;
  final Color accent;
  final Color ring;
  final bool searching;

  _RadarPainter({
    required this.animation,
    required this.accent,
    required this.ring,
    required this.searching,
  }) : super(repaint: animation);

  double get t => animation.value;

  void _dashedCircle(Canvas canvas, Offset c, double r, Paint paint, {int dashes = 48}) {
    final sweep = 2 * math.pi / dashes;
    final rect = Rect.fromCircle(center: c, radius: r);
    for (int i = 0; i < dashes; i++) {
      canvas.drawArc(rect, i * sweep, sweep * 0.45, false, paint);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;

    canvas.drawCircle(c, r * 0.92, Paint()..color = accent.withValues(alpha: 0.045));
    canvas.drawCircle(c, r * 0.58, Paint()..color = accent.withValues(alpha: 0.07));

    _dashedCircle(
      canvas, c, r * 0.96,
      Paint()
        ..color = ring.withValues(alpha: 0.40)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..strokeCap = StrokeCap.round,
    );

    if (searching) {
      // Rotating sweep: a conic gradient fading in to the leading edge
      final sweepPaint = Paint()
        ..shader = SweepGradient(
          colors: [accent.withValues(alpha: 0), accent.withValues(alpha: 0.32)],
          stops: const [0.0, 1.0],
          transform: GradientRotation(t * 2 * math.pi),
        ).createShader(Rect.fromCircle(center: c, radius: r * 0.92));
      canvas.drawCircle(c, r * 0.92, sweepPaint);

      // Leading edge line of the sweep
      final angle = t * 2 * math.pi;
      canvas.drawLine(
        c,
        Offset(c.dx + math.cos(angle) * r * 0.92, c.dy + math.sin(angle) * r * 0.92),
        Paint()
          ..color = accent.withValues(alpha: 0.75)
          ..strokeWidth = 1.6
          ..strokeCap = StrokeCap.round,
      );

      // Two staggered pulses
      for (int i = 0; i < 2; i++) {
        final p = (t * 1.4 + i / 2) % 1.0;
        canvas.drawCircle(
          c,
          r * (0.22 + 0.70 * Curves.easeOutCubic.transform(p)),
          Paint()
            ..color = accent.withValues(alpha: (1 - p) * 0.35)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.8,
        );
      }
    }

    // Centre: you
    canvas.drawCircle(c, r * 0.13, Paint()..color = accent.withValues(alpha: 0.22));
    canvas.drawCircle(c, r * 0.075, Paint()..color = accent);
    canvas.drawCircle(
      c, r * 0.075,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant _RadarPainter old) =>
      old.accent != accent || old.ring != ring || old.searching != searching || old.animation != animation;
}
