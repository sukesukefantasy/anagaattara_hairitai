import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../../../../system/automation_ability_catalog.dart';
import '../../../../system/automation_tool_kind.dart';
import '../../../enemy/enemy_base.dart';
import 'automation_tool_base.dart';

/// 自動防衛（igniter）— 近接・遠距離・スローデバフ。
class WardAutomationTool extends AutomationToolBase {
  double _attackCooldown = 0;

  WardAutomationTool({
    required super.instanceId,
    required super.position,
  }) : super(kind: AutomationToolKind.ward);

  @override
  Color pulseColor() => const Color(0xFFFF6644);

  @override
  void tickTool(double dt) {
    if (!state.isAutomationUnlocked(AutomationUnlockIds.wardMelee)) return;

    _attackCooldown -= dt;
    if (_attackCooldown > 0) return;

    final range = state.wardMeleeRange();
    final damage = state.wardMeleeDamage();
    if (range <= 0 || damage <= 0) return;

    final scene = game.sceneManager.currentScene;
    if (scene == null) return;

    EnemyBase? target;
    var bestDist = range + 1;
    for (final e in scene.children.whereType<EnemyBase>()) {
      if (!e.isMounted) continue;
      final d = (absoluteCenter - e.absoluteCenter).length;
      if (d < bestDist) {
        bestDist = d;
        target = e;
      }
    }

    if (target == null) return;

    final impulse = Vector2(
      (target.absoluteCenter.x - absoluteCenter.x).sign * 40,
      -20,
    );
    target.takeDamage(damage, impulse: impulse);

    if (state.isAutomationUnlocked(AutomationUnlockIds.wardSlow)) {
      target.velocity.x *= 0.7;
    }

    if (state.isAutomationUnlocked(AutomationUnlockIds.wardRanged) &&
        bestDist > range * 0.6) {
      target.takeDamage(damage * 0.5);
    }

    _attackCooldown = state.wardAttackInterval();
  }
}
