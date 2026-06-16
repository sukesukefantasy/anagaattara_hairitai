/// 屋外ステージごとのローグ戦闘上限（§5 ローグ駆け引き仕様 v0.1）。
class StageCombatProfile {
  final int maxWalkingEnemies;
  final int maxCarEnemies;
  final int maxCombatTier;
  final int minCombatTier;
  final int initialWalkingSpawn;
  final int initialCarSpawn;
  final double spawnIntervalSeconds;
  final double residuePullMultiplier;
  final double telegraphBaseSeconds;

  const StageCombatProfile({
    required this.maxWalkingEnemies,
    required this.maxCarEnemies,
    required this.maxCombatTier,
    this.minCombatTier = 0,
    required this.initialWalkingSpawn,
    required this.initialCarSpawn,
    this.spawnIntervalSeconds = 0.2,
    this.residuePullMultiplier = 1.0,
    this.telegraphBaseSeconds = 0.42,
  });

  static const StageCombatProfile _defaultOutdoor = StageCombatProfile(
    maxWalkingEnemies: 10,
    maxCarEnemies: 1,
    maxCombatTier: 2,
    initialWalkingSpawn: 8,
    initialCarSpawn: 1,
  );

  static const Map<String, StageCombatProfile> byOutdoorId = {
    'outdoor_0': StageCombatProfile(
      maxWalkingEnemies: 0,
      maxCarEnemies: 0,
      maxCombatTier: 0,
      minCombatTier: 0,
      initialWalkingSpawn: 0,
      initialCarSpawn: 0,
      spawnIntervalSeconds: 0.2,
    ),
    'outdoor_1': StageCombatProfile(
      maxWalkingEnemies: 8,
      maxCarEnemies: 1,
      maxCombatTier: 1,
      initialWalkingSpawn: 6,
      initialCarSpawn: 1,
    ),
    'outdoor_2': StageCombatProfile(
      maxWalkingEnemies: 14,
      maxCarEnemies: 2,
      maxCombatTier: 2,
      initialWalkingSpawn: 10,
      initialCarSpawn: 2,
      residuePullMultiplier: 1.05,
    ),
    'outdoor_3': StageCombatProfile(
      maxWalkingEnemies: 18,
      maxCarEnemies: 2,
      maxCombatTier: 3,
      initialWalkingSpawn: 14,
      initialCarSpawn: 2,
      spawnIntervalSeconds: 0.18,
      residuePullMultiplier: 1.10,
    ),
    'outdoor_4': StageCombatProfile(
      maxWalkingEnemies: 22,
      maxCarEnemies: 3,
      maxCombatTier: 3,
      minCombatTier: 2,
      initialWalkingSpawn: 18,
      initialCarSpawn: 3,
      spawnIntervalSeconds: 0.14,
      residuePullMultiplier: 1.22,
      telegraphBaseSeconds: 0.32,
    ),
  };

  static StageCombatProfile forScene(String? outdoorSceneId) {
    if (outdoorSceneId == null) return _defaultOutdoor;
    return byOutdoorId[outdoorSceneId] ?? _defaultOutdoor;
  }

  /// [starAlertLevel]（0–10）から既存 HP ティア 0–3 へ。
  static int alertToCombatTier(double starAlertLevel) {
    if (starAlertLevel >= 6.0) return 3;
    if (starAlertLevel >= 4.0) return 2;
    if (starAlertLevel >= 2.0) return 1;
    return 0;
  }

  /// 警戒とステージ上限を合成した敵ティア。
  int effectiveCombatTier(double starAlertLevel) {
    final fromAlert = alertToCombatTier(starAlertLevel);
    final capped = fromAlert.clamp(0, maxCombatTier);
    return capped < minCombatTier ? minCombatTier : capped;
  }

  /// HUD・演出用 0–4。
  static int starAlertHudTier(double starAlertLevel) {
    if (starAlertLevel >= 8.0) return 4;
    if (starAlertLevel >= 6.0) return 3;
    if (starAlertLevel >= 4.0) return 2;
    if (starAlertLevel >= 2.0) return 1;
    return 0;
  }

  static double maxHealthForTier(int tier) => switch (tier) {
        3 => 30.0,
        2 => 20.0,
        1 => 15.0,
        _ => 10.0,
      };

  static double enemyRunScaleForTier(int tier, double starAlertLevel) {
    final alertExtra = starAlertLevel * 0.04;
    return 1.0 + tier * 0.06 + alertExtra;
  }

  int clipWalkingCap(int scheduleCap) =>
      scheduleCap > maxWalkingEnemies ? maxWalkingEnemies : scheduleCap;

  int clipCarCap(int scheduleCap) =>
      scheduleCap > maxCarEnemies ? maxCarEnemies : scheduleCap;
}
