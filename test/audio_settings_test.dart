import 'package:flutter_test/flutter_test.dart';
import 'package:lift_load/game/cast.dart';
import 'package:lift_load/game/engine.dart';
import 'package:lift_load/game/scenario.dart';
import 'package:lift_load/game/venue.dart';
import 'package:lift_load/services/ads_service.dart';
import 'package:lift_load/services/analytics_service.dart';
import 'package:lift_load/services/feedback_service.dart';
import 'package:lift_load/services/profile.dart';
import 'package:lift_load/ui/game_controller.dart';

import 'helpers.dart';

class RecordingAudio implements GameAudio {
  final List<Sfx> played = [];
  final List<Venue> venues = [];
  bool sound = true, music = true;

  @override
  void play(Sfx cue) => played.add(cue);

  @override
  set soundOn(bool on) => sound = on;

  @override
  set musicOn(bool on) => music = on;

  @override
  void playVenue(Venue venue) => venues.add(venue);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final now = DateTime(2026, 10, 21);

  group('profile settings', () {
    test('round-trip through JSON', () {
      final p = Profile.fresh(now)
        ..soundOn = false
        ..musicOn = true
        ..hapticsOn = false;
      final back = Profile.fromJson(p.toJson(), now);
      expect(back.soundOn, isFalse);
      expect(back.musicOn, isTrue);
      expect(back.hapticsOn, isFalse);
    });

    test('saves from before the settings existed default to everything on', () {
      final old = Profile.fresh(now).toJson()
        ..remove('soundOn')
        ..remove('musicOn')
        ..remove('hapticsOn');
      final back = Profile.fromJson(old, now);
      expect(back.soundOn && back.musicOn && back.hapticsOn, isTrue);
      expect(back.level, 1);
    });
  });

  group('feedback cues', () {
    const r = Resident(id: 1, type: ResidentType.kid, floor: Floor.coral);
    const heavy = Resident(id: 2, type: ResidentType.bellhop, floor: Floor.coral);

    List<Sfx> cuesFor(GameEvent e) {
      final audio = RecordingAudio();
      FeedbackService(sfx: audio, hapticsOn: false).on(e);
      return audio.played;
    }

    test('every event maps to its fixed cue', () {
      expect(cuesFor(const SelectedEvent(r)), [Sfx.select]);
      expect(cuesFor(const SeatedEvent(r, 0)), [Sfx.seat]);
      expect(cuesFor(const RefusedEvent(r, [Floor.teal])), [Sfx.refuse]);
      expect(cuesFor(const BoardedEvent(r, LoadZone.light)), [Sfx.board]);
      expect(cuesFor(const BoardedEvent(r, LoadZone.limit)), [Sfx.creak]);
      expect(cuesFor(const OverloadEvent(r)), [Sfx.snap]);
      expect(cuesFor(const SentEvent([Floor.coral], LiftKind.normal, TripRating.halfEmpty, 0, 1)), [Sfx.doorClose]);
      expect(cuesFor(const SentEvent([Floor.coral], LiftKind.normal, TripRating.perfect, 15, 3)),
          [Sfx.doorClose, Sfx.coin]);
      expect(cuesFor(const LiftArrivedEvent([Floor.teal], LiftKind.normal)), [Sfx.ding]);
      expect(cuesFor(const ArrivalsEvent(4)), [Sfx.chime]);
      expect(cuesFor(const LaneOpenedEvent(2)), [Sfx.clank]);
      expect(cuesFor(const WonEvent(40, 5, 1)), [Sfx.fanfare]);
      expect(cuesFor(const FailedEvent(FailKind.crash)), [Sfx.crash]);
      expect(cuesFor(const FailedEvent(FailKind.jam)), [Sfx.fail]);
      expect(cuesFor(const ContinuedEvent(FailKind.jam)), [Sfx.doorOpen]);
    });

    test('boarding sounds the same whoever boards (weights stay hidden)', () {
      expect(cuesFor(const BoardedEvent(r, LoadZone.green)), cuesFor(const BoardedEvent(heavy, LoadZone.green)));
      expect(cuesFor(const SeatedEvent(r, 1)), cuesFor(const SeatedEvent(heavy, 1)));
    });
  });

  group('controller', () {
    GameController make(RecordingAudio audio, Profile profile) => GameController(
          profile: profile,
          ads: StubAdsService(delay: Duration.zero),
          analytics: DebugAnalytics(),
          audio: audio,
          levelFor: (_) => variety(Venue.hotel, LiftKind.normal, null),
        );

    test('settings reach audio and haptics, and are saved in the profile', () {
      final audio = RecordingAudio();
      final p = Profile.fresh(now)..musicOn = false;
      final c = make(audio, p);
      expect(audio.music, isFalse, reason: 'applied at start');
      c.setSound(false);
      expect(audio.sound, isFalse);
      expect(p.soundOn, isFalse);
      c.setHaptics(false);
      expect(c.feedback.hapticsOn, isFalse);
      c.setMusic(true);
      expect(audio.music, isTrue);
    });

    test('starting a level plays its venue music', () {
      final audio = RecordingAudio();
      make(audio, Profile.fresh(now)).startLevel();
      expect(audio.venues, [Venue.hotel]);
    });
  });
}
