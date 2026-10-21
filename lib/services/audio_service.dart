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
  AudioService({AudioVoice Function(String id, {required bool music})? voice}) : _newVoice = voice ?? PlayerVoice.new;

  static const double musicVolume = 0.35;
  static const int voicesPerCue = 2;
  static const Duration fade = Duration(milliseconds: 600);
  static const int fadeSteps = 12;

  /// Music loops are Ogg Vorbis natively (gapless loop seam) and MP3 on the
  /// web (older Safari has no Vorbis). See tool/audio/synth.py.
  static String musicAsset(Venue venue) => 'music/${venue.name}.${kIsWeb ? 'mp3' : 'ogg'}';

  final AudioVoice Function(String id, {required bool music}) _newVoice;
  final Map<Sfx, List<AudioVoice>> _voices = {};
  final Map<Sfx, int> _next = {};
  late final AudioVoice _music = _newVoice('music', music: true);
  Venue? _venue;
  Venue? _loaded;
  bool _soundOn = true;
  bool _musicOn = true;
  bool _hidden = false;
  Timer? _fadeTimer;

  /// Bumped whenever the wanted music state changes. A music start that
  /// finishes loading after a newer change (switch off, app hidden, another
  /// venue) sees a stale generation and stops instead of playing.
  int _gen = 0;

  /// Loads every cue at once (serial loading takes seconds per cue on the
  /// web). Each cue becomes playable as soon as its own voices are ready, and
  /// one failed cue does not stop the others.
  Future<void> init() => Future.wait([for (final cue in Sfx.values) _load(cue)]);

  Future<void> _load(Sfx cue) async {
    try {
      final voices = [for (var i = 0; i < voicesPerCue; i++) _newVoice('sfx_${cue.file}_$i', music: false)];
      await Future.wait([for (final v in voices) v.load('sfx/${cue.file}.mp3', loop: false)]);
      _voices[cue] = voices;
    } on Object catch (e) {
      debugPrint('Audio: ${cue.file} failed to load: $e');
    }
  }

  @override
  set soundOn(bool on) => _soundOn = on;

  @override
  set musicOn(bool on) {
    if (on == _musicOn) return;
    _musicOn = on;
    _sync();
  }

  @override
  void play(Sfx cue) {
    if (!_soundOn || _hidden) return;
    final voices = _voices[cue];
    if (voices == null || voices.isEmpty) return;
    final i = (_next[cue] ?? 0) % voices.length;
    _next[cue] = i + 1;
    _guard(voices[i].restart());
  }

  @override
  void playVenue(Venue venue) {
    if (venue == _venue) return;
    _venue = venue;
    _sync();
  }

  /// App went to the background / came back.
  void pause() {
    _hidden = true;
    _sync();
  }

  void resume() {
    _hidden = false;
    _sync();
  }

  /// Brings the music player in line with the wanted state: silent when the
  /// switch is off, the app is hidden or no venue is set; otherwise the
  /// venue's loop, fading in when it (re)starts.
  void _sync() {
    final gen = ++_gen;
    _fadeTimer?.cancel();
    final venue = _venue;
    if (!_musicOn || _hidden || venue == null) {
      _guard(_music.pause());
      return;
    }
    _guard(_start(venue, gen));
  }

  Future<void> _start(Venue venue, int gen) async {
    if (_loaded != venue) {
      await _music.stop();
      if (gen != _gen) return;
      _loaded = null;
      await _music.load(musicAsset(venue), loop: true);
      if (gen != _gen) return;
      _loaded = venue;
    }
    await _music.setVolume(0);
    if (gen != _gen) return;
    await _music.resume();
    if (gen != _gen) return;
    var step = 0;
    _fadeTimer = Timer.periodic(fade ~/ fadeSteps, (t) {
      if (gen != _gen) return t.cancel();
      step++;
      _guard(_music.setVolume(musicVolume * step / fadeSteps));
      if (step >= fadeSteps) t.cancel();
    });
  }

  void _guard(Future<void> f) {
    f.catchError((Object e) => debugPrint('Audio: $e'));
  }
}

/// The few player operations [AudioService] needs, so tests can stand in a
/// fake for the platform player.
abstract interface class AudioVoice {
  Future<void> load(String asset, {required bool loop});

  /// Plays a cue from the start, cutting off this voice's previous play.
  Future<void> restart();
  Future<void> resume();
  Future<void> pause();
  Future<void> stop();
  Future<void> setVolume(double volume);
}

/// An [AudioVoice] on an audioplayers [AudioPlayer].
///
/// Audio focus: on Android every player asks for full focus by default, and
/// the focus stack is per player, so each cue would permanently take focus
/// from our own music (which then pauses) and from other apps. Cues therefore
/// mix with others and never take focus; only the music asks for it.
class PlayerVoice implements AudioVoice {
  PlayerVoice(String id, {required this.music}) : _player = AudioPlayer(playerId: id);

  final bool music;
  final AudioPlayer _player;

  static final AudioContext cueContext = AudioContextConfig(focus: AudioContextConfigFocus.mixWithOthers).build();

  @override
  Future<void> load(String asset, {required bool loop}) async {
    if (!music) {
      // Short cues: Android's SoundPool path, much lighter than 34 prepared
      // MediaPlayers.
      await _player.setPlayerMode(PlayerMode.lowLatency);
      await _player.setAudioContext(cueContext);
    }
    await _player.setReleaseMode(loop ? ReleaseMode.loop : ReleaseMode.stop);
    await _player.setSource(AssetSource(asset));
  }

  @override
  Future<void> restart() => _player.stop().then((_) => _player.resume());

  @override
  Future<void> resume() => _player.resume();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> setVolume(double volume) => _player.setVolume(volume);
}
