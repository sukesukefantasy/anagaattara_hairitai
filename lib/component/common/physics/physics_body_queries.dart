import 'dart:math';
import 'dart:ui' show Rect;

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';

import 'physics_step_obstacle.dart';

/// ヒットボックス優先の物理 AABB とトンネル半径。
abstract final class PhysicsBodyQueries {
  /// プレイヤー既定の物理ヒットボックス（[Player] の [RectangleHitbox] と同じ）。
  static const double defaultPlayerHitboxWidth = 20;
  static const double defaultPlayerHitboxHeight = 50;

  /// 既定プレイヤー向けのトンネル半径（掘削・通行の基準）。
  static double get defaultPassageRadius => passageRadiusFor(
        Rect.fromLTWH(
          0,
          0,
          defaultPlayerHitboxWidth,
          defaultPlayerHitboxHeight,
        ),
      );

  static double get defaultPassageDiameter => defaultPassageRadius * 2;

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

  /// [Anchor.bottomCenter] 向け: ヒットボックス下端を足元 (local y = size.y) に揃える。
  static ({Vector2 position, Vector2 size}) feetAlignedHitbox(
    Vector2 bodySize, {
    required double widthRatio,
    required double heightRatio,
    required double centerXRatio,
  }) {
    final hitboxSize = Vector2(
      bodySize.x * widthRatio,
      bodySize.y * heightRatio,
    );
    return (
      position: Vector2(
        bodySize.x * centerXRatio - hitboxSize.x / 2,
        bodySize.y - hitboxSize.y,
      ),
      size: hitboxSize,
    );
  }
}
