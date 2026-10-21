import 'package:flutter/services.dart';

import '../game/engine.dart';
import '../game/venue.dart';

/// Turns game events into haptics and sound cues.
///
/// Every cue is a fixed sound per event. Nothing depends on who is moving or
/// how heavy they are; the creak follows the gauge zone, which the player
/// already sees.
class FeedbackService {
  FeedbackService({SfxPlayer? sfx, this.hapticsOn = true}) : _sfx = sfx ?? const SilentAudio();

  final SfxPlayer _sfx;

  /// Player setting; sounds are switched in the audio service itself.
  bool hapticsOn;

  void _haptic(Future<void> Function() f) {
    if (hapticsOn) f();
  }

  void on(GameEvent e) {
    switch (e) {
      case SelectedEvent():
        _haptic(HapticFeedback.selectionClick);
        _sfx.play(Sfx.select);
      case SeatedEvent():
        _haptic(HapticFeedback.lightImpact);
        _sfx.play(Sfx.seat);
      case RefusedEvent():
        _haptic(HapticFeedback.lightImpact);
        _sfx.play(Sfx.refuse);
      case BoardedEvent(:final zone):
        _haptic(HapticFeedback.lightImpact);
        _sfx.play(zone == LoadZone.limit ? Sfx.creak : Sfx.board);
      case OverloadEvent():
        _haptic(HapticFeedback.heavyImpact);
        _sfx.play(Sfx.snap);
      case SentEvent(:final coins):
        _haptic(HapticFeedback.mediumImpact);
        _sfx.play(Sfx.doorClose);
        if (coins > 0) _sfx.play(Sfx.coin);
      case LiftArrivedEvent():
        _sfx.play(Sfx.ding);
      case ArrivalsEvent():
        _haptic(HapticFeedback.lightImpact);
        _sfx.play(Sfx.chime);
      case LaneOpenedEvent():
        _haptic(HapticFeedback.selectionClick);
        _sfx.play(Sfx.clank);
      case ScalePreviewEvent():
        _sfx.play(Sfx.tick);
      case WonEvent():
        _haptic(HapticFeedback.mediumImpact);
        _sfx.play(Sfx.fanfare);
      case FailedEvent(:final kind):
        _haptic(HapticFeedback.heavyImpact);
        _sfx.play(kind == FailKind.crash ? Sfx.crash : Sfx.fail);
      case ContinuedEvent():
        _sfx.play(Sfx.doorOpen);
    }
  }

  /// A plain UI tap (buttons, toggles).
  void tap() {
    _haptic(HapticFeedback.selectionClick);
    _sfx.play(Sfx.ui);
  }
}

/// Sound cues; [file] is the asset under assets/sfx/.
enum Sfx {
  tick('tick'),
  select('select'),
  seat('seat'),
  board('board'),
  doorClose('door_close'),
  doorOpen('door_open'),
  ding('ding'),
  creak('creak'),
  snap('snap'),
  crash('crash'),
  coin('coin'),
  refuse('refuse'),
  fanfare('fanfare'),
  fail('fail'),
  chime('chime'),
  clank('clank'),
  ui('ui');

  const Sfx(this.file);
  final String file;
}

abstract interface class SfxPlayer {
  void play(Sfx cue);
}

/// Everything the game asks of audio: cues, venue music, and the player's
/// switches. M1 tests use [SilentAudio]; the app uses `AudioService`.
abstract interface class GameAudio implements SfxPlayer {
  set soundOn(bool on);
  set musicOn(bool on);

  /// Start (or keep) the venue's music loop.
  void playVenue(Venue venue);
}

class SilentAudio implements GameAudio {
  const SilentAudio();

  @override
  void play(Sfx cue) {}

  @override
  set soundOn(bool on) {}

  @override
  set musicOn(bool on) {}

  @override
  void playVenue(Venue venue) {}
}
