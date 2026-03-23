import 'package:flutter/material.dart';

/// BINDE.GG Level & Ranking System
///
/// - 50 levels, each level = 300 ELO
/// - 10 tiers of 5 levels each
/// - Prestige after level 50 (ELO continues, level cycles back)
/// - 1v1/2v2: +30 win / -29 loss
/// - 5v5: +60 win / -59 loss
class LevelSystem {
  LevelSystem._();

  static const int eloPerLevel = 300;
  static const int maxLevel = 50;
  static const int eloPerPrestige = eloPerLevel * maxLevel; // 15,000

  // ELO changes per mode
  static const int elo1v1Win = 30;
  static const int elo1v1Loss = 29;
  static const int elo2v2Win = 30;
  static const int elo2v2Loss = 29;
  static const int elo5v5Win = 60;
  static const int elo5v5Loss = 59;

  /// Get ELO change for a match result.
  static ({int win, int loss}) eloForMode(String mode) {
    return switch (mode) {
      '5v5' => (win: elo5v5Win, loss: elo5v5Loss),
      '2v2' => (win: elo2v2Win, loss: elo2v2Loss),
      _ => (win: elo1v1Win, loss: elo1v1Loss),
    };
  }

  /// Calculate level (1-50) from ELO.
  static int levelFromElo(int elo) {
    if (elo < 0) return 1;
    final cycleElo = elo % eloPerPrestige;
    final level = (cycleElo ~/ eloPerLevel) + 1;
    return level.clamp(1, maxLevel);
  }

  /// Calculate prestige count from ELO.
  static int prestigeFromElo(int elo) {
    if (elo < eloPerPrestige) return 0;
    return elo ~/ eloPerPrestige;
  }

  /// ELO progress within current level (0.0 to 1.0).
  static double progressInLevel(int elo) {
    if (elo < 0) return 0;
    final cycleElo = elo % eloPerPrestige;
    return (cycleElo % eloPerLevel) / eloPerLevel;
  }

  /// ELO needed to reach next level.
  static int eloToNextLevel(int elo) {
    if (elo < 0) return eloPerLevel;
    final cycleElo = elo % eloPerPrestige;
    return eloPerLevel - (cycleElo % eloPerLevel);
  }

  /// Get tier info for a level.
  static LevelTier tierForLevel(int level) {
    final index = ((level - 1) ~/ 5).clamp(0, tiers.length - 1);
    return tiers[index];
  }

  /// All 10 tiers.
  static const List<LevelTier> tiers = [
    LevelTier(name: 'Iron',     levels: (1, 5),   color: Color(0xFF6B7280), icon: '⬡'),
    LevelTier(name: 'Bronze',   levels: (6, 10),  color: Color(0xFFCD7F32), icon: '⬡'),
    LevelTier(name: 'Silver',   levels: (11, 15), color: Color(0xFFA8B4C0), icon: '⬡'),
    LevelTier(name: 'Gold',     levels: (16, 20), color: Color(0xFFFFD700), icon: '⬢'),
    LevelTier(name: 'Platinum', levels: (21, 25), color: Color(0xFFB8D4E3), icon: '⬢'),
    LevelTier(name: 'Diamond',  levels: (26, 30), color: Color(0xFF7EE8FA), icon: '◆'),
    LevelTier(name: 'Master',   levels: (31, 35), color: Color(0xFF9B59B6), icon: '◆'),
    LevelTier(name: 'Champion', levels: (36, 40), color: Color(0xFFE74C3C), icon: '★'),
    LevelTier(name: 'Legend',   levels: (41, 45), color: Color(0xFFF39C12), icon: '★'),
    LevelTier(name: 'Elite',    levels: (46, 50), color: Color(0xFF3DAFB8), icon: '✦'),
  ];
}

class LevelTier {
  final String name;
  final (int, int) levels; // (min, max)
  final Color color;
  final String icon;
  const LevelTier({required this.name, required this.levels, required this.color, required this.icon});
}
