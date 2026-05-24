import 'package:flame/components.dart';

/// ノックバック・接触反応の調整用定数。
///
/// ゲームバランス調整は **このファイルだけ** を編集する想定。
abstract final class KnockbackConfig {
  // --- プレイヤー ---

  static const double playerMass = 42.0;

  /// 接触ノックバック中、入力による velocity.x 上書きを抑える時間（秒）。
  static const double playerKnockbackDuration = 0.25;

  /// 同一相手からの接触ノックバック再適用までの最短間隔（秒）。衝突ジッター対策。
  static const double contactKnockbackCooldown = 0.35;

  /// 接触 → プレイヤーへの全体倍率。
  static const double contactImpulseScale = 1.5;

  /// 基準質量（[CarEnemy] の mass と揃える）。これより軽い敵は飛び量を抑える。
  static const double contactReferenceMass = 100.0;

  /// ほぼ静止接触時の最低速度（px/s）。
  static const double minContactSpeed = 30.0;

  /// 接触ノックバックの水平速度上限（px/s）。極端な速度＝物理サブステップ増加を防ぐ。
  static const double maxContactDeltaVX = 80.0;

  /// 地上・水平衝突時の小跳ね（|Δv.x| × この係数）。
  static const double contactGroundBounceFromHorizontal = 0.06;

  /// 敵接触時の残滓バースト再スポーン間隔（秒）。パフォーマンス対策。
  static const double contactResidueBurstCooldown = 0.6;

  // --- swing → 敵 ---

  /// 素手想定の item mass。
  static const double meleeBareHandMass = 0.5;

  /// 素手 swing の目標水平速度（px/s）。
  static const double meleeBareHandHorizontalSpeed = 50.0;

  /// 棒（[meleeStickBaselineMass]）swing の目標水平速度（px/s）。
  static const double meleeStickHorizontalSpeed = 80.0;

  /// 棒の item mass（item.dart の「棒」と一致）。
  static const double meleeStickBaselineMass = 0.8;

  /// 垂直ノックバック = 水平 × この比率。
  static const double meleeVerticalRatio = 0.12;

  /// 棒より重いツールの吹っ飛ばし倍率（1.0〜1.35）。
  static double meleeToolKnockbackMultiplier(double itemMass) {
    if (itemMass <= meleeStickBaselineMass) return 1.0;
    return (1.0 + (itemMass - meleeStickBaselineMass) * 0.15).clamp(1.0, 1.35);
  }

  /// swing ヒット時の目標水平速度（px/s）。
  static double meleeHorizontalSpeed(double itemMass, double scale) {
    final base = itemMass <= meleeBareHandMass + 1e-6
        ? meleeBareHandHorizontalSpeed
        : meleeStickHorizontalSpeed * meleeToolKnockbackMultiplier(itemMass);
    return base * scale;
  }

  /// swing ヒット時の目標上方向速度（px/s、正の値）。
  static double meleeVerticalSpeed(double itemMass, double scale) =>
      meleeHorizontalSpeed(itemMass, scale) * meleeVerticalRatio;

  /// swing 用 impulse（[EnemyBase.applyKnockback] で /enemyMass され目標速度になる）。
  static Vector2 meleeImpulse({
    required double itemMass,
    required double enemyMass,
    required double facingX,
    required double scale,
  }) {
    final targetV = Vector2(
      facingX * meleeHorizontalSpeed(itemMass, scale),
      -meleeVerticalSpeed(itemMass, scale),
    );
    return targetV * enemyMass;
  }
}
