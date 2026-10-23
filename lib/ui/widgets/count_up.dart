/// A number that counts to its new value and bounces (the coin counters, the
/// coins on the win sheet). Timings in [CountMotion]. Under reduced motion it
/// shows the new value at once and holds still.
library;

import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../motion.dart';

class CountUp extends StatefulWidget {
  const CountUp({
    super.key,
    required this.value,
    required this.builder,
    this.from,
    this.delay = Duration.zero,
    this.duration = CountMotion.count,
    this.onTick,
  });

  /// Where it counts to.
  final int value;

  /// Where it first counts from (null: it starts at [value], no count).
  final int? from;

  /// Waits this long before the first count.
  final Duration delay;
  final Duration duration;

  /// Called [CountMotion.ticks] times through a count (the tick cue).
  final VoidCallback? onTick;

  /// Builds the number: [shown] now, and [widest], the longer of where it
  /// started and where it ends, to reserve room so the layout never jitters.
  final Widget Function(BuildContext context, int shown, int widest) builder;

  @override
  State<CountUp> createState() => _CountUpState();
}

class _CountUpState extends State<CountUp> with TickerProviderStateMixin {
  late final AnimationController _count = AnimationController(vsync: this);
  late final AnimationController _bounce = AnimationController(vsync: this, duration: CountMotion.bounce);
  late int _start = widget.from ?? widget.value;
  late int _widest = widget.value;
  int _ticked = 0;
  bool _started = false;
  bool _counting = false;

  @override
  void initState() {
    super.initState();
    _count.addStatusListener(_landed);
  }

  int get _shown => (_start + (widget.value - _start) * Curves.easeOutCubic.transform(_progress)).round();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (_start != widget.value) {
      _go();
    } else {
      _count.value = 1;
    }
  }

  @override
  void didUpdateWidget(CountUp old) {
    super.didUpdateWidget(old);
    if (old.value == widget.value) return;
    // Where the number was showing when the new value came: that is where it
    // counts on from.
    _start = (_start + (old.value - _start) * Curves.easeOutCubic.transform(_progress)).round();
    _go();
  }

  void _go() {
    if (reduceMotion(context)) {
      _start = widget.value;
      _count.value = 1;
      return;
    }
    _widest = math.max(_start.abs(), widget.value.abs());
    _ticked = 0;
    _count.duration = widget.delay + widget.duration;
    _count
      ..removeListener(_tick)
      ..addListener(_tick)
      ..forward(from: 0);
    _counting = true;
  }

  /// It lands with a bounce.
  void _landed(AnimationStatus status) {
    if (status != AnimationStatus.completed || !_counting) return;
    _counting = false;
    _bounce.forward(from: 0);
  }

  /// 0 to 1 over the count itself, 0 while it waits.
  double get _progress {
    final total = _count.duration;
    if (widget.delay == Duration.zero || total == null || _count.value >= 1) return _count.value;
    return ((_count.value * total.inMicroseconds - widget.delay.inMicroseconds) / widget.duration.inMicroseconds)
        .clamp(0, 1)
        .toDouble();
  }

  void _tick() {
    final due = (_progress * CountMotion.ticks).floor();
    while (_ticked < due) {
      _ticked++;
      widget.onTick?.call();
    }
  }

  @override
  void dispose() {
    _count.dispose();
    _bounce.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: Listenable.merge([_count, _bounce]),
        builder: (context, _) {
          final b = _bounce.isAnimating ? math.sin(math.pi * _bounce.value) : 0.0;
          return Transform.scale(
            scale: 1 + CountMotion.bounceScale * b,
            child: widget.builder(context, _shown, math.max(_widest, widget.value.abs())),
          );
        },
      );
}

/// [text] laid out in [style], so a counting number can keep the width of its
/// widest value and nothing around it jitters while the digits change.
class StableText extends StatelessWidget {
  const StableText(this.text, {super.key, required this.widest, required this.style, this.align = Alignment.center});

  /// What shows now, and the widest string it will show.
  final String text, widest;
  final TextStyle style;
  final Alignment align;

  @override
  Widget build(BuildContext context) {
    final painter = TextPainter(
      text: TextSpan(text: widest, style: DefaultTextStyle.of(context).style.merge(style)),
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final width = painter.width;
    painter.dispose();
    return SizedBox(width: width, child: Align(alignment: align, child: Text(text, style: style, maxLines: 1, softWrap: false)));
  }
}
