import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import '../game/venue.dart';
import 'feedback_service.dart';

/// Plays the synthesized cues (assets/sfx) and venue loops (assets/music)
/// with audioplayers. Audio must never break play: every call is
/// fire-and-forget and failures are only logged.
///
/// Browsers block sound until the first user gesture; the first cue or
/// music start happens on a tap (Play), so that is satisfied.
class AudioService implements GameAudio {
  AudioService();

  static const double musicVolume = 0.35;
  static const int voicesPerCue = 2;
  static const Duration fade = Duration(milliseconds: 600);

  final Map<Sfx, List<AudioPlayer>> _voices = {};
  final Map<Sfx, int> _next = {};
  final AudioPlayer _music = AudioPlayer(playerId: 'music');
  Venue? _venue;
  bool _musicPlaying = false;
  bool _soundOn = true;
  bool _musicOn = true;
  Timer? _fadeTimer;

  /// Loads every cue at once (serial loading takes seconds per cue on the
  /// web). Each cue becomes playable as soon as its own voices are ready, and
  /// one failed cue does not stop the others.
  Future<void> init() async {
    _guard(_music.setReleaseMode(ReleaseMode.loop));
    await Future.wait([for (final cue in Sfx.values) _load(cue)]);
  }

  Future<void> _load(Sfx cue) async {
    try {
      final voices = [for (var i = 0; i < voicesPerCue; i++) AudioPlayer(playerId: 'sfx_${cue.file}_$i')];
      await Future.wait([
        for (final p in voices)
          p.setReleaseMode(ReleaseMode.stop).then((_) => p.setSource(AssetSource('sfx/${cue.file}.mp3'))),
      ]);
      _voices[cue] = voices;
    } on Object catch (e) {
      debugPrint('Audio: ${cue.file} failed to load: $e');
    }
  }

  @override
  set soundOn(bool on) => _soundOn = on;

  @override
  set musicOn(bool on) {
    _musicOn = on;
    if (!on) {
      _guard(_music.pause());
      _musicPlaying = false;
    } else if (_venue != null) {
      final v = _venue!;
      _venue = null;
      playVenue(v);
    }
  }

  @override
  void play(Sfx cue) {
    if (!_soundOn) return;
    final voices = _voices[cue];
    if (voices == null || voices.isEmpty) return;
    final i = (_next[cue] ?? 0) % voices.length;
    _next[cue] = i + 1;
    final p = voices[i];
    _guard(p.stop().then((_) => p.resume()));
  }

  @override
  void playVenue(Venue venue) {
    if (_venue == venue && (_musicPlaying || !_musicOn)) return;
    _venue = venue;
    if (!_musicOn) return;
    _guard(_startMusic(venue));
  }

  Future<void> _startMusic(Venue venue) async {
    _fadeTimer?.cancel();
    await _music.stop();
    await _music.setSource(AssetSource('music/${venue.name}.mp3'));
    await _music.setVolume(0);
    await _music.resume();
    _musicPlaying = true;
    const steps = 12;
    var step = 0;
    _fadeTimer = Timer.periodic(fade ~/ steps, (t) {
      step++;
      _guard(_music.setVolume(musicVolume * step / steps));
      if (step >= steps) t.cancel();
    });
  }

  /// App went to the background / came back.
  void pause() {
    _guard(_music.pause());
  }

  void resume() {
    if (_musicOn && _musicPlaying) _guard(_music.resume());
  }

  void _guard(Future<void> f) {
    f.catchError((Object e) => debugPrint('Audio: $e'));
  }
}
