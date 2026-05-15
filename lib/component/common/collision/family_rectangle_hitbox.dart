import 'package:flame/collisions.dart';

import 'collision_family.dart';

/// ファミリーを明示的に持つ矩形ヒットボックス。
class FamilyRectangleHitbox extends RectangleHitbox implements HitboxCollisionTag {
  FamilyRectangleHitbox({
    required this.collisionFamily,
    super.position,
    super.size,
    super.anchor,
    super.angle,
    super.collisionType,
    super.isSolid,
  });

  @override
  final CollisionFamily collisionFamily;
}
