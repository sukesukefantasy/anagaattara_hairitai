import 'dart:math';
import 'dart:ui' show Rect;

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';

import 'physics_step_obstacle.dart';

/// ヒットボックス優先の物理 AABB とトンネル半径。
abstract final class PhysicsBodyQueries {
  /// 子の [RectangleHitbox] があればそのワールド AABB、なければコンポーネント全体。
  static Rect physicsAabb(PositionComponent body) {
    RectangleHitbox? hitbox;
    for (final child in body.children) {
      if (child is RectangleHitbox) {
        hitbox = child;
        break;
      }
    }
    if (hitbox == null) {
      return PhysicsStepQueries.absoluteAabb(body);
    }
    final abs = body.absolutePosition;
    final tlx = abs.x - body.anchor.x * body.size.x;
    final tly = abs.y - body.anchor.y * body.size.y;
    return Rect.fromLTWH(
      tlx + hitbox.position.x,
      tly + hitbox.position.y,
      hitbox.size.x,
      hitbox.size.y,
    );
  }

  /// ヒットボックスを覆う円形トンネルの半径（掘削・通行・描画で共有）。
  static double passageRadiusFor(Rect aabb) {
    final hw = aabb.width / 2;
    final hh = aabb.height / 2;
    return sqrt(hw * hw + hh * hh) + 2;
  }

  static double passageRadiusForBody(PositionComponent body) =>
      passageRadiusFor(physicsAabb(body));
}
