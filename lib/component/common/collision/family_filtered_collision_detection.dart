import 'package:flame/collisions.dart';
import 'package:flame/components.dart';

import 'collision_family.dart';

/// [collisionFamiliesInteract] に基づき、衝突コールバックをフィルタする。
///
/// Broadphase は従来どおりペアを生成するが、`handleCollision*` 前に除外する。
class FamilyFilteredCollisionDetection extends StandardCollisionDetection {
  FamilyFilteredCollisionDetection({super.broadphase});

  bool _allow(ShapeHitbox a, ShapeHitbox b) {
    return collisionFamiliesInteract(
      collisionFamilyOf(a),
      collisionFamilyOf(b),
    );
  }

  @override
  void handleCollisionStart(
    Set<Vector2> intersectionPoints,
    ShapeHitbox hitboxA,
    ShapeHitbox hitboxB,
  ) {
    if (!_allow(hitboxA, hitboxB)) return;
    super.handleCollisionStart(intersectionPoints, hitboxA, hitboxB);
  }

  @override
  void handleCollision(
    Set<Vector2> intersectionPoints,
    ShapeHitbox hitboxA,
    ShapeHitbox hitboxB,
  ) {
    if (!_allow(hitboxA, hitboxB)) return;
    super.handleCollision(intersectionPoints, hitboxA, hitboxB);
  }

  @override
  void handleCollisionEnd(ShapeHitbox hitboxA, ShapeHitbox hitboxB) {
    if (!_allow(hitboxA, hitboxB)) return;
    super.handleCollisionEnd(hitboxA, hitboxB);
  }
}
