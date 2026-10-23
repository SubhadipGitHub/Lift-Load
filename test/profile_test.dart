import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lift_load/game/powers.dart';
import 'package:lift_load/services/profile.dart';

void main() {
  final now = DateTime(2026, 10, 22, 9);

  test('a fresh profile owns no powers and is right-handed', () {
    final p = Profile.fresh(now);
    for (final power in Power.values) {
      expect(p.stock(power), 0, reason: '${power.name} starts at zero (PRD v1.6)');
    }
    expect(p.leftHanded, isFalse);
  });

  test('sprite art is on by default, saves, and an older save loads with it on', () {
    expect(Profile.fresh(now).useSpriteArt, isTrue);
    final off = Profile.fresh(now)..useSpriteArt = false;
    expect(Profile.fromJson(jsonDecode(jsonEncode(off.toJson())) as Map<String, dynamic>, now).useSpriteArt, isFalse);
    final old = Profile.fresh(now).toJson()..remove('useSpriteArt');
    expect(Profile.fromJson(jsonDecode(jsonEncode(old)) as Map<String, dynamic>, now).useSpriteArt, isTrue);
  });

  test('stock goes up with addPower and down with spendPower, never below zero', () {
    final p = Profile.fresh(now);
    expect(p.spendPower(Power.swap), isFalse);
    p.addPower(Power.swap, 2);
    expect(p.spendPower(Power.swap), isTrue);
    expect(p.spendPower(Power.swap), isTrue);
    expect(p.spendPower(Power.swap), isFalse);
    expect(p.stock(Power.swap), 0);
  });

  test('powers and the left-handed switch survive a save and load', () {
    final p = Profile.fresh(now)
      ..leftHanded = true
      ..addPower(Power.trip, 3)
      ..addPower(Power.express, 1);
    final back = Profile.fromJson(jsonDecode(jsonEncode(p.toJson())) as Map<String, dynamic>, now);
    expect(back.leftHanded, isTrue);
    expect(back.stock(Power.trip), 3);
    expect(back.stock(Power.express), 1);
    expect(back.stock(Power.swap), 0);
    expect(p.toJson()['v'], Profile.version);
  });

  test('a version 1 save loads with zero of each power and a right-handed bar', () {
    final v1 = Profile.fresh(now).toJson()
      ..['v'] = 1
      ..['level'] = 33
      ..['coins'] = 410
      ..remove('powers')
      ..remove('leftHanded');
    final p = Profile.fromJson(jsonDecode(jsonEncode(v1)) as Map<String, dynamic>, now);
    expect(p.level, 33);
    expect(p.coins, 410);
    expect(p.leftHanded, isFalse);
    for (final power in Power.values) {
      expect(p.stock(power), 0);
    }
  });

  test('one bad power entry costs only that power, not the profile', () {
    final j = Profile.fresh(now).toJson()
      ..['level'] = 40
      ..['adsRemoved'] = true
      ..['powers'] = {'swap': '2', 'seats': -5, 'trip': 3, 'express': 99999};
    final p = Profile.fromJson(jsonDecode(jsonEncode(j)) as Map<String, dynamic>, now);
    expect(p.level, 40);
    expect(p.adsRemoved, isTrue);
    expect(p.stock(Power.swap), 0);
    expect(p.stock(Power.seats), 0);
    expect(p.stock(Power.trip), 3);
    expect(p.stock(Power.express), 999);
  });

  test('an unreadable stored save starts a fresh profile instead of throwing', () {
    final good = jsonEncode(Profile.fresh(now).toJson());
    for (final raw in [null, '', 'not json', good.substring(0, good.length ~/ 2), '[1,2]', '"text"']) {
      final p = Profile.fromStored(raw, now);
      expect(p.level, 1, reason: 'for $raw');
      expect(p.coins, Profile.fresh(now).coins);
    }
    expect(Profile.fromStored(jsonEncode((Profile.fresh(now)..level = 7).toJson()), now).level, 7);
  });
}
