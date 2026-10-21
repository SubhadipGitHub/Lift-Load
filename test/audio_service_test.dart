import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lift_load/game/venue.dart';
import 'package:lift_load/services/audio_service.dart';
import 'package:lift_load/services/feedback_service.dart';

/// Records what the service asks of a player. Music loads can be held open to
/// model the web, where a source takes seconds to load.
class FakeVoice implements AudioVoice {
  FakeVoice(this.id);

  final String id;
  final List<String> calls = [];
  bool playing = false;
  String? source;
  double volume = 1;
  Completer<void>? hold;

  @override
  Future<void> load(String asset, {required bool loop}) async {
    calls.add('load $asset');
    final h = hold;
    if (h != null) await h.future;
    source = asset;
  }

  @override
  Future<void> restart() async {
    calls.add('restart');
    playing = true;
  }

  @override
  Future<void> resume() async {
    calls.add('resume');
    playing = true;
  }

  @override
  Future<void> pause() async {
    calls.add('pause');
    playing = false;
  }

  @override
  Future<void> stop() async {
    calls.add('stop');
    playing = false;
  }

  @override
  Future<void> setVolume(double v) async => volume = v;
}

void main() {
  late Map<String, FakeVoice> voices;
  late AudioService audio;
  FakeVoice music() => voices['music']!;

  setUp(() {
    voices = {};
    audio = AudioService(voice: (id, {required music}) => voices[id] = FakeVoice(id));
  });

  test('music starts with a fade to the mix volume', () {
    fakeAsync((async) {
      audio.playVenue(Venue.mall);
      async.elapse(const Duration(seconds: 1));
      expect(music().playing, isTrue);
      expect(music().source, AudioService.musicAsset(Venue.mall));
      expect(music().volume, closeTo(AudioService.musicVolume, 1e-9));
    });
  });

  test('flipping the music switch to the value it already has leaves the music alone', () {
    fakeAsync((async) {
      audio.playVenue(Venue.mall);
      async.elapse(const Duration(seconds: 1));
      music().calls.clear();
      audio.musicOn = true; // what the controller does on every settings change
      async.elapse(const Duration(seconds: 1));
      expect(music().calls, isEmpty);
    });
  });

  test('music switched off while the loop is still loading stays silent', () {
    fakeAsync((async) {
      audio.playVenue(Venue.mall);
      async.flushMicrotasks();
      music().hold = Completer();
      // Restart the load under the hold (a fresh venue) to model a slow source.
      audio.playVenue(Venue.hotel);
      async.flushMicrotasks();
      audio.musicOn = false;
      music().hold!.complete();
      async.elapse(const Duration(seconds: 1));
      expect(music().playing, isFalse);
    });
  });

  test('going to the background while the loop is loading stays silent, and coming back plays it', () {
    fakeAsync((async) {
      final hold = Completer<void>();
      audio.playVenue(Venue.office);
      // The load is held from the first call.
      music().hold = hold;
      audio
        ..playVenue(Venue.mall)
        ..pause();
      hold.complete();
      async.elapse(const Duration(seconds: 1));
      expect(music().playing, isFalse);
      audio.resume();
      async.elapse(const Duration(seconds: 1));
      expect(music().playing, isTrue);
      expect(music().source, AudioService.musicAsset(Venue.mall));
    });
  });

  test('two quick venue changes end on the last venue with one fade', () {
    fakeAsync((async) {
      audio
        ..playVenue(Venue.society)
        ..playVenue(Venue.hospital);
      async.elapse(const Duration(seconds: 2));
      expect(music().source, AudioService.musicAsset(Venue.hospital));
      expect(music().playing, isTrue);
      expect(music().volume, closeTo(AudioService.musicVolume, 1e-9));
      expect(async.periodicTimerCount, 0);
    });
  });

  test('cues round-robin their voices and respect the sound switch', () {
    fakeAsync((async) {
      audio.init();
      async.flushMicrotasks();
      audio.play(Sfx.coin);
      audio.play(Sfx.coin);
      expect(voices['sfx_coin_0']!.calls.last, 'restart');
      expect(voices['sfx_coin_1']!.calls.last, 'restart');
      audio.soundOn = false;
      voices['sfx_coin_0']!.calls.clear();
      audio.play(Sfx.coin);
      expect(voices['sfx_coin_0']!.calls, isEmpty);
    });
  });

  test('cues mix with other audio and never take audio focus', () {
    expect(PlayerVoice.cueContext.android.audioFocus, AndroidAudioFocus.none);
  });
}
