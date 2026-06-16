import 'dart:math';
import 'dart:ui';

import 'walking_enemy.dart';
import '../../system/alert_hunter_tool_drop.dart';

/// 警戒ティア上昇時に出現する中ボス（AlertHunter）。
class AlertHunterEnemy extends WalkingEnemy {
  static const double _hunterSpeed = 135.0;
  static const double _baseAttackStress = 12.0;
  static const double _contactMassMultiplier = 2.5;

  double _pulsePhase = 0.0;

  AlertHunterEnemy({
    required super.position,
    required super.direction,
  }) : super(
          mass: 85,
          walkCycleSpeed: 9.5,
          priority: 46,
          fixedSpriteRowIndex: WalkingEnemy.alertHunterSpriteRowIndex,
          offScreenDespawn: false,
          chasePlayer: true,
        );

  @override
  double get speed => _hunterSpeed;

  @override
  double get attackStress => _baseAttackStress;

  @override
  double get maxHealthMultiplier => 4.0;

  @override
  bool get alwaysShowHealthBar => true;

  @override
  double get contactMass => mass * _contactMassMultiplier;

  @override
  bool get useAttackTelegraph => false;

  @override
  void update(double dt) {
    super.update(dt);
    _pulsePhase += dt * 5.0;
    final pulse = 0.22 + sin(_pulsePhase) * 0.12;
    paint.colorFilter = ColorFilter.mode(
      Color.lerp(
        const Color(0xFFFF6666),
        const Color(0xFFFF1111),
        (sin(_pulsePhase * 0.7) + 1) * 0.5,
      )!
          .withValues(alpha: pulse),
      BlendMode.srcATop,
    );
    scale.y = 1.0 + sin(_pulsePhase) * 0.05;
  }

  @override
  void dieAndDropItem() {
    final state = game.gameRuntimeState;
    final grant = state.nextHunterToolToGrant();
    if (grant != null) {
      state.grantToolFromHunter(grant);
      final item = createAutomationToolItem(
        grant,
        absolutePosition.clone(),
      );
      if (item != null) {
        game.player.itemBag.addItem(item);
      }
      state.pendingKitFromHunterNotice = true;
    }
    super.dieAndDropItem();
  }
}
