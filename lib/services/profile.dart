import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../game/formulas.dart';
import '../game/powers.dart';
import 'ad_policy.dart';

/// Everything saved on the device. Offline-first: no account, no server.
class Profile {
  Profile({
    required this.level,
    required this.coins,
    required this.lives,
    required this.livesStampedAt,
    required this.scales,
    required this.winStreak,
    required this.adsRemoved,
    required this.rewarded,
    this.soundOn = true,
    this.musicOn = true,
    this.hapticsOn = true,
    this.leftHanded = false,
    Map<int, int>? attempts,
    Map<Power, int>? powers,
  })  : attempts = attempts ?? {},
        powers = powers ?? {for (final p in Power.values) p: Formulas.startingPowerStock};

  /// Save format. 2 added the powers and the left-handed switch; a version 1 save
  /// loads with zero of each power and the switch off.
  static const int version = 2;

  factory Profile.fresh(DateTime now) => Profile(
        level: 1,
        coins: Formulas.startingCoins,
        lives: Formulas.maxLives,
        livesStampedAt: now,
        scales: Formulas.startingScales,
        winStreak: 0,
        adsRemoved: false,
        rewarded: RewardedBudget(day: RewardedBudget.dayKey(now)),
      );

  int level;
  int coins;
  int lives;

  /// When [lives] was last counted; regen accrues from here.
  DateTime livesStampedAt;
  int scales;
  int winStreak;
  bool adsRemoved;
  final RewardedBudget rewarded;

  /// Settings sheet switches.
  bool soundOn;
  bool musicOn;
  bool hapticsOn;

  /// Mirrors the bottom bar (Send left, powers right).
  bool leftHanded;

  /// Uses owned of each power, bought with coins or earned from a rewarded ad.
  final Map<Power, int> powers;

  int stock(Power p) => powers[p] ?? 0;
  void addPower(Power p, int n) => powers[p] = stock(p) + n;

  /// Spends one use; false when there is none.
  bool spendPower(Power p) {
    if (stock(p) <= 0) return false;
    powers[p] = stock(p) - 1;
    return true;
  }

  /// How many times each level has been started, so analytics can tell a
  /// first attempt from a retry.
  final Map<int, int> attempts;

  /// Apply life regeneration up to [now].
  void regenLives(DateTime now) {
    if (lives >= Formulas.maxLives) {
      livesStampedAt = now;
      return;
    }
    final gained = now.difference(livesStampedAt).inSeconds ~/ Formulas.lifeRegen.inSeconds;
    if (gained <= 0) return;
    lives = (lives + gained).clamp(0, Formulas.maxLives).toInt();
    livesStampedAt = lives >= Formulas.maxLives ? now : livesStampedAt.add(Formulas.lifeRegen * gained);
  }

  /// Time until the next life, or null when full.
  Duration? nextLifeIn(DateTime now) {
    if (lives >= Formulas.maxLives) return null;
    final elapsed = now.difference(livesStampedAt);
    final left = Formulas.lifeRegen - elapsed;
    return left.isNegative ? Duration.zero : left;
  }

  void spendLife(DateTime now) {
    regenLives(now);
    if (lives >= Formulas.maxLives) livesStampedAt = now;
    if (lives > 0) lives--;
  }

  Map<String, Object> toJson() => {
        'v': version,
        'level': level,
        'coins': coins,
        'lives': lives,
        'livesStampedAt': livesStampedAt.toIso8601String(),
        'scales': scales,
        'winStreak': winStreak,
        'adsRemoved': adsRemoved,
        'rewardedDay': rewarded.day,
        'rewardedUsed': rewarded.used,
        'soundOn': soundOn,
        'musicOn': musicOn,
        'hapticsOn': hapticsOn,
        'leftHanded': leftHanded,
        'powers': {for (final e in powers.entries) e.key.name: e.value},
        'attempts': {for (final e in attempts.entries) '${e.key}': e.value},
      };

  /// Stock per power from a save. One bad entry costs only that power, never
  /// the rest of the profile.
  static Map<Power, int> _powersFrom(Object? raw) {
    final saved = raw is Map ? raw : const {};
    return {
      for (final p in Power.values)
        p: switch (saved[p.name]) {
          final num n => n.toInt().clamp(0, 999).toInt(),
          _ => Formulas.startingPowerStock,
        },
    };
  }

  /// A save as stored: null (first run), or text that may be truncated or not
  /// JSON at all. Anything unreadable starts a fresh profile rather than
  /// stopping the app at the splash.
  static Profile fromStored(String? raw, DateTime now) {
    if (raw == null) return Profile.fresh(now);
    try {
      return fromJson(jsonDecode(raw) as Map<String, dynamic>, now);
    } on Object {
      return Profile.fresh(now);
    }
  }

  static Profile fromJson(Map<String, dynamic> j, DateTime now) {
    try {
      return Profile(
        level: (j['level'] as num).toInt(),
        coins: (j['coins'] as num).toInt(),
        lives: (j['lives'] as num).toInt(),
        livesStampedAt: DateTime.parse(j['livesStampedAt'] as String),
        scales: (j['scales'] as num).toInt(),
        winStreak: (j['winStreak'] as num).toInt(),
        adsRemoved: j['adsRemoved'] as bool,
        rewarded: RewardedBudget(
          day: j['rewardedDay'] as String,
          used: {
            for (final e in (j['rewardedUsed'] as Map<String, dynamic>).entries) e.key: (e.value as num).toInt(),
          },
        ),
        // Saves from before the settings existed default to everything on.
        soundOn: j['soundOn'] as bool? ?? true,
        musicOn: j['musicOn'] as bool? ?? true,
        hapticsOn: j['hapticsOn'] as bool? ?? true,
        leftHanded: j['leftHanded'] as bool? ?? false,
        powers: _powersFrom(j['powers']),
        attempts: {
          for (final e in (j['attempts'] as Map<String, dynamic>? ?? const {}).entries)
            int.parse(e.key): (e.value as num).toInt(),
        },
      );
    } on Object {
      return Profile.fresh(now);
    }
  }
}

/// Loads and saves [Profile] as one JSON string.
class ProfileStore {
  ProfileStore(this._prefs);

  static const _key = 'lift_load.profile.v1';
  final SharedPreferences _prefs;

  static Future<ProfileStore> open() async => ProfileStore(await SharedPreferences.getInstance());

  Profile load(DateTime now) {
    final profile = Profile.fromStored(_prefs.getString(_key), now);
    profile.regenLives(now);
    return profile;
  }

  Future<void> save(Profile p) => _prefs.setString(_key, jsonEncode(p.toJson()));
}
