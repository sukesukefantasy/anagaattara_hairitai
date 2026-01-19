import 'package:flame/components.dart';
import 'package:anagaattara_hairitai/component/common/hitboxes/physics_hitbox.dart';
import 'package:flutter/foundation.dart';

/// 物理挙動を定義するミックスイン
class PhysicsBehavior implements HasPhysicsHitbox {
  Vector2 velocity; // 速度 (pixel/s)
  double mass; // 質量 (kg)
  double gravity; // 重力加速度 (pixel/s^2)
  final PositionComponent parent;
  bool isEnabled; // 物理挙動が有効かどうかを制御するフラグ

  @override
  PhysicsHitbox? hitbox;

  PhysicsBehavior({
    required this.parent,
    this.mass = 1.0,
    this.gravity = 9.8 * 10, // 仮の値、調整が必要
    Vector2? initialVelocity,
    this.isEnabled = true, // デフォルトでは物理挙動を有効にする
  }) : velocity = initialVelocity ?? Vector2.zero();

  void applyPhysics(double dt) {
    if (!isEnabled) return;

    // 重力を適用
    velocity.y += gravity * dt;

    // 速度に基づいて位置を更新
    parent.position += velocity * dt;

    // 衝突中でない場合のみ、空気抵抗のような緩やかな摩擦を適用
    if (hitbox?.isColliding == false) {
      if (velocity.x.abs() > 0) {
        velocity.x *= (1 - 0.1 * dt).clamp(0.0, 1.0); // 軽い空気抵抗
        if (velocity.x.abs() < 0.1) {
          velocity.x = 0;
        }
      }
      if (velocity.y.abs() > 0) {
        velocity.y *= (1 - 0.1 * dt).clamp(0.0, 1.0); // 軽い空気抵抗
        if (velocity.y.abs() < 0.1) {
          velocity.y = 0;
        }
      }
    }
  }

  // 速度を設定するメソッド
  void setVelocity(Vector2 newVelocity) {
    velocity = newVelocity;
  }

  // 質量を設定するメソッド
  void setMass(double newMass) {
    mass = newMass;
  }

  // 重力を設定するメソッド
  void setGravity(double newGravity) {
    gravity = newGravity;
  }

  void setEnabled(bool newEnabled) {
    isEnabled = newEnabled;
  }

  // ヒットボックスを設定するメソッド
  void setHitbox(PhysicsHitbox newHitbox) {
    hitbox = newHitbox;
    debugPrint('PhysicsBehavior: Hitbox set: $hitbox');
  }
}

abstract class HasPhysicsHitbox {
  PhysicsHitbox? get hitbox;
}
