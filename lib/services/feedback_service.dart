import 'package:flutter/services.dart';

import '../game/engine.dart';

/// Turns game events into haptics and sound cues.
///
/// Sound: the eight OGG cues (tick, ding, creak, snap, thud, coin, refuse,
/// fanfare) are recorded in M4; [SfxPlayer] is the hook they plug into.
class FeedbackService {
  FeedbackService({SfxPlayer? sfx}) : _sfx = sfx ?? const SilentSfx();

  final SfxPlayer _sfx;

  void on(GameEvent e) {
    switch (e) {
      case SelectedEvent():
        HapticFeedback.selectionClick();
        _sfx.play(Sfx.tick);
      case SeatedEvent():
        HapticFeedback.lightImpact();
        _sfx.play(Sfx.thud);
      case RefusedEvent():
        HapticFeedback.lightImpact();
        _sfx.play(Sfx.refuse);
      case BoardedEvent(:final zone):
        HapticFeedback.lightImpact();
        _sfx.play(zone == LoadZone.limit ? Sfx.creak : Sfx.tick);
      case OverloadEvent():
        HapticFeedback.heavyImpact();
        _sfx.play(Sfx.snap);
      case SentEvent():
        HapticFeedback.mediumImpact();
        _sfx.play(Sfx.ding);
      case ArrivalsEvent():
        HapticFeedback.lightImpact();
        _sfx.play(Sfx.thud);
      case LaneOpenedEvent():
        HapticFeedback.selectionClick();
        _sfx.play(Sfx.tick);
      case WonEvent():
        HapticFeedback.mediumImpact();
        _sfx.play(Sfx.fanfare);
      case ScalePreviewEvent() || LiftArrivedEvent() || FailedEvent() || ContinuedEvent():
        break;
    }
  }
}

enum Sfx { tick, ding, creak, snap, thud, coin, refuse, fanfare }

abstract interface class SfxPlayer {
  void play(Sfx cue);
}

class SilentSfx implements SfxPlayer {
  const SilentSfx();

  @override
  void play(Sfx cue) {}
}
