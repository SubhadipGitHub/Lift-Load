import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../layout.dart';
import '../motion.dart';
import '../theme.dart';
import 'lobby.dart';

/// Every pointer that may drag a scroll view on this screen: a finger, a
/// mouse (Flutter's default leaves the mouse out, so a desktop browser could
/// only scroll with the wheel), a trackpad and a stylus.
const Set<PointerDeviceKind> playDragDevices = {
  PointerDeviceKind.touch,
  PointerDeviceKind.mouse,
  PointerDeviceKind.trackpad,
  PointerDeviceKind.stylus,
  PointerDeviceKind.invertedStylus,
};

/// The scroll behaviour for the play screen: every pointer drags, the bars
/// are ours, and the content always scrolls with a soft bounce.
class PlayScrollBehavior extends MaterialScrollBehavior {
  const PlayScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => playDragDevices;

  @override
  Widget buildScrollbar(BuildContext context, Widget child, ScrollableDetails details) => child;

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics());
}

/// The lobby lanes' scroll area. Touch, mouse drag, trackpad and wheel all
/// scroll it; a thin bar and a fade at the top or bottom edge show that more
/// lies that way. A tap on a card still selects: a drag only starts past the
/// platform's touch slop.
///
/// The queues draw only [Metrics.visibleDepth] people, so scrolling never
/// shows how many wait.
class LaneScroller extends StatefulWidget {
  const LaneScroller({super.key, required this.child});

  final Widget child;

  /// Finds the scrollable in tests.
  static const Key scrollKey = ValueKey('lane-scroll');

  /// The fades that say more lies above or below, when they show.
  static const Key fadeTopKey = ValueKey('lane-fade-top');
  static const Key fadeBottomKey = ValueKey('lane-fade-bottom');

  @override
  State<LaneScroller> createState() => _LaneScrollerState();
}

class _LaneScrollerState extends State<LaneScroller> {
  final ScrollController _controller = ScrollController();
  bool _more = false, _less = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Reads where the content is after each layout and scroll.
  bool _onMetrics(ScrollMetrics metrics) {
    final less = metrics.extentBefore > Metrics.scrollCueEdge;
    final more = metrics.extentAfter > Metrics.scrollCueEdge;
    if (less != _less || more != _more) {
      // Metrics arrive during layout; the cue repaints on the next frame.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _less = less;
          _more = more;
        });
      });
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final m = Metrics.of(context);
    return ScrollConfiguration(
      behavior: const PlayScrollBehavior(),
      child: NotificationListener<ScrollMetricsNotification>(
        onNotification: (n) => _onMetrics(n.metrics),
        child: NotificationListener<ScrollNotification>(
          onNotification: (n) => _onMetrics(n.metrics),
          child: Stack(
            children: [
              // The bar rides in the gutter beside the floor, clear of the cards.
              RawScrollbar(
                controller: _controller,
                thumbVisibility: true,
                interactive: true,
                thickness: m.scrollBar,
                radius: Radius.circular(m.scrollBar),
                crossAxisMargin: m.scrollBarMargin,
                mainAxisMargin: m.laneTop,
                thumbColor: LL.scrollThumb,
                child: LayoutBuilder(
                  builder: (context, box) => SingleChildScrollView(
                    key: LaneScroller.scrollKey,
                    controller: _controller,
                    primary: false,
                    child: ConstrainedBox(constraints: BoxConstraints(minHeight: box.maxHeight), child: widget.child),
                  ),
                ),
              ),
              // Shades over the floor's top and bottom edge while more lies past it.
              Positioned.fill(
                left: m.gap,
                right: m.gap,
                child: IgnorePointer(
                  child: ClipRRect(
                    borderRadius: QueueLanes.floorRadius(m),
                    child: Column(
                      children: [
                        _Fade(key: LaneScroller.fadeTopKey, shown: _less, top: true),
                        const Spacer(),
                        _Fade(key: LaneScroller.fadeBottomKey, shown: _more, top: false),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A soft shade over the floor's edge, there only while more lies past it.
class _Fade extends StatelessWidget {
  const _Fade({super.key, required this.shown, required this.top});

  final bool shown;
  final bool top;

  @override
  Widget build(BuildContext context) {
    final m = Metrics.of(context);
    return AnimatedOpacity(
      opacity: shown ? 1 : 0,
      duration: motionMs(context, 180),
      child: Container(
        height: m.scrollFade,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: top ? Alignment.topCenter : Alignment.bottomCenter,
            end: top ? Alignment.bottomCenter : Alignment.topCenter,
            colors: const [LL.scrollFade, LL.scrollFadeClear],
          ),
        ),
      ),
    );
  }
}
