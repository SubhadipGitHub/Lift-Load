import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../game/formulas.dart';
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
  });

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

  /// Apply life regeneration up to [now].
  void regenLives(DateTime now) {
    if (lives >= Formulas.maxLives) {
      livesStampedAt = now;
      return;
    }
    final gained = now.difference(livesStampedAt).inSeconds ~/ Formulas.lifeRegen.inSeconds;
    if (gained <= 0) return;
    lives = (lives + gained).clamp(0, Formulas.maxLives).toInt();
    livesStampedAt = lives >= Formulas.maxLives
        ? now
        : livesStampedAt.add(Formulas.lifeRegen * gained);
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
        'v': 1,
        'level': level,
        'coins': coins,
        'lives': lives,
        'livesStampedAt': livesStampedAt.toIso8601String(),
        'scales': scales,
        'winStreak': winStreak,
        'adsRemoved': adsRemoved,
        'rewardedDay': rewarded.day,
        'rewardedUsed': rewarded.used,
      };

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
    final raw = _prefs.getString(_key);
    final profile = raw == null ? Profile.fresh(now) : Profile.fromJson(jsonDecode(raw) as Map<String, dynamic>, now);
    profile.regenLives(now);
    return profile;
  }

  Future<void> save(Profile p) => _prefs.setString(_key, jsonEncode(p.toJson()));
}
