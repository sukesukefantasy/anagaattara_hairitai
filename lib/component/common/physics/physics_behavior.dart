import 'package:flame/components.dart';
import 'package:anagaattara_hairitai/component/common/hitboxes/physics_hitbox.dart';
import 'package:anagaattara_hairitai/component/common/physics/entity_physics_mixin.dart';
import 'package:flutter/foundation.dart';

/// 物理挙動を定義するファサード。[EntityPhysicsMixin] の velocity を委譲する。
class PhysicsBehavior implements HasPhysicsHitbox {
  double mass; // 質量 (kg)
  final PositionComponent parent;
  bool isEnabled; // 物理挙動が有効かどうかを制御するフラグ

  @override
  PhysicsHitbox? hitbox;

  EntityPhysicsMixin get _physicsMixin => parent as EntityPhysicsMixin;

  Vector2 get velocity => _physicsMixin.velocity;
  set velocity(Vector2 value) => _physicsMixin.velocity = value;

  PhysicsBehavior({
    required this.parent,
    this.mass = 1.0,
    Vector2? initialVelocity,
    this.isEnabled = false,
  }) {
    if (initialVelocity != null) {
      _physicsMixin.velocity = initialVelocity;
    }
  }

  void setEnabled(bool newEnabled) {
    isEnabled = newEnabled;
  }

  void setVelocity(Vector2 newVelocity) {
    velocity = newVelocity;
  }

  void setMass(double newMass) {
    mass = newMass;
  }

  void setGravity(double newGravity) {
    _physicsMixin.gravityScale = newGravity / EntityPhysicsMixin.kGravity;
  }

  void setHitbox(PhysicsHitbox newHitbox) {
    hitbox = newHitbox;
    debugPrint('PhysicsBehavior: Hitbox set: $hitbox');
  }
}

abstract class HasPhysicsHitbox {
  PhysicsHitbox? get hitbox;
}
