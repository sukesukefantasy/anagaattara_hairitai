import 'dart:math';
import 'dart:ui' show Rect;

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';

import '../collision/collision_family.dart';
import '../terrain/terrain_field.dart';
import 'physics_body_queries.dart';
import 'physics_step_obstacle.dart';

/// サブステップ＋軸分離スイープによる運動学移動（トンネリング防止）。
class KinematicMovement {
  static const double defaultMaxStep = 16.0;
  static const double defaultGravity = 700.0;

  /// 物理用 dt の上限（秒）。レンダー dt が大きくても1ステップの移動量を抑える。
  static const double maxPhysicsDt = 1.0 / 30.0;

  static double clampPhysicsDt(double dt) => min(dt, maxPhysicsDt);

  static KinematicMoveResult integrate({
    required PositionComponent body,
    required Vector2 velocity,
    required double dt,
    required KinematicConfig config,
    TerrainField? terrain,
    List<Rect> staticSlabs = const [],
    void Function(Vector2 previousWorld, Vector2 newWorld)? onPositionApplied,
  }) {
    dt = clampPhysicsDt(dt);
    velocity.x = velocity.x.clamp(-config.maxHorizontalSpeed, config.maxHorizontalSpeed);

    var isOnGround = config.startOnGround;
    var hitCeiling = false;
    var hitWall = false;

    if (config.applyGravity && !isOnGround) {
      velocity.y = min(
        velocity.y + config.gravity * config.gravityScale * dt,
        config.maxFallSpeed,
      );
    }

    var remaining = velocity * dt;
    final maxStep = config.maxStepSize;
    var prevWorld = body.absoluteCenter;

    while (remaining.length > 1e-4) {
      final stepLen = min(remaining.length, maxStep);
      final step = remaining.normalized() * stepLen;
      remaining -= step;

      if (!config.enableHorizontal) {
        step.x = 0;
      }
      if (!config.enableVertical) {
        step.y = 0;
      }

      // X
      if (step.x.abs() > 1e-6) {
        final movedX = _moveAxis(
          body: body,
          delta: step.x,
          horizontal: true,
          terrain: terrain,
          staticSlabs: staticSlabs,
          config: config,
        );
        if (movedX.abs() < step.x.abs() - 1e-4) {
          velocity.x = 0;
          hitWall = true;
        }
      }

      // Y
      if (step.y.abs() > 1e-6) {
        final wasOnGround = isOnGround;
        final movedY = _moveAxis(
          body: body,
          delta: step.y,
          horizontal: false,
          terrain: terrain,
          staticSlabs: staticSlabs,
          config: config,
        );
        if (movedY.abs() < step.y.abs() - 1e-4) {
          if (step.y > 0) {
            velocity.y = 0;
            isOnGround = true;
          } else {
            velocity.y = 0;
            hitCeiling = true;
          }
        } else if (step.y > 0 && !wasOnGround) {
          isOnGround = false;
        }
        if (step.y < 0) {
          isOnGround = false;
        }
      }

      final newWorld = body.absoluteCenter;
      onPositionApplied?.call(prevWorld, newWorld);
      prevWorld = newWorld;
    }

    if (config.enableFootSnap) {
      final snapped = _snapFeetOntoSlabs(
        body: body,
        velocity: velocity,
        staticSlabs: staticSlabs,
        isOnGround: isOnGround,
      );
      isOnGround = snapped || isOnGround;
    }

    return KinematicMoveResult(
      isOnGround: isOnGround,
      hitCeiling: hitCeiling,
      hitWall: hitWall,
    );
  }

  static double _moveAxis({
    required PositionComponent body,
    required double delta,
    required bool horizontal,
    required TerrainField? terrain,
    required List<Rect> staticSlabs,
    required KinematicConfig config,
  }) {
    var moved = 0.0;
    var remaining = delta.abs();
    final sign = delta.sign;

    while (remaining > 1e-6) {
      final chunk = min(remaining, config.maxStepSize) * sign;
      final before = PhysicsBodyQueries.physicsAabb(body);
      body.position += horizontal ? Vector2(chunk, 0) : Vector2(0, chunk);
      final after = PhysicsBodyQueries.physicsAabb(body);

      final terrainHit = terrain != null && terrain.isBlocked(after);
      final slabHit = _slabBlocks(after, staticSlabs, horizontal, sign, before);

      if (terrainHit || slabHit) {
        body.position -= horizontal ? Vector2(chunk, 0) : Vector2(0, chunk);
        break;
      }
      moved += chunk;
      remaining -= chunk.abs();
    }
    return moved;
  }

  static bool _slabBlocks(
    Rect aabb,
    List<Rect> slabs,
    bool horizontal,
    double sign,
    Rect before,
  ) {
    for (final slab in slabs) {
      if (!aabb.overlaps(slab)) continue;

      final ox = PhysicsStepQueries.axisOverlap(
        aabb.left,
        aabb.right,
        slab.left,
        slab.right,
      );
      final oy = PhysicsStepQueries.axisOverlap(
        aabb.top,
        aabb.bottom,
        slab.top,
        slab.bottom,
      );
      if (ox <= 0 || oy <= 0) continue;

      if (horizontal) {
        if (ox >= oy) continue;
        final towardWall = slab.center.dx >= before.center.dx ? 1.0 : -1.0;
        if (sign == towardWall) return true;
      } else {
        if (oy > ox) continue;
        if (sign > 0 && aabb.bottom > slab.top + 0.5) {
          // 落下で床に当たった
          if (aabb.center.dy >= slab.top) return true;
        }
        if (sign < 0 && aabb.top < slab.bottom - 0.5) {
          return true;
        }
      }
    }
    return false;
  }

  static bool _snapFeetOntoSlabs({
    required PositionComponent body,
    required Vector2 velocity,
    required List<Rect> staticSlabs,
    required bool isOnGround,
  }) {
    if (velocity.y < -120) return isOnGround;
    final mine = PhysicsBodyQueries.physicsAabb(body);
    double? bestTop;
    for (final slab in staticSlabs) {
      final ox = PhysicsStepQueries.axisOverlap(
        mine.left,
        mine.right,
        slab.left,
        slab.right,
      );
      if (ox <= 0) continue;
      final pen = mine.bottom - slab.top;
      if (pen < -3 || pen > max(72.0, body.size.y * 0.42) + slab.height * 0.5) {
        continue;
      }
      bestTop = bestTop == null ? slab.top : min(bestTop, slab.top);
    }
    if (bestTop != null && mine.bottom > bestTop) {
      final drift = mine.bottom - bestTop;
      if (drift > 0.5 && drift < 200) {
        body.position.y -= drift;
        if (velocity.y > 2) velocity.y = 0;
        return true;
      }
    }
    return isOnGround;
  }

  /// [CollisionCallbacks] の _solidCollisions から地形スラブを収集。
  static List<Rect> collectTerrainSlabs(
    Iterable<PositionComponent> solidCollisions,
  ) {
    final slabs = <Rect>[];
    for (final raw in solidCollisions) {
      if (!raw.isMounted) continue;
      final root = PhysicsStepQueries.solidRoot(
        raw is ShapeHitbox ? raw.parent! as PositionComponent : raw,
      );
      final CollisionFamily family = root is HasCollisionFamily
          ? (root as HasCollisionFamily).collisionFamily
          : CollisionFamily.unspecified;
      if (family != CollisionFamily.terrain &&
          family != CollisionFamily.unspecified) {
        continue;
      }
      slabs.add(PhysicsStepQueries.absoluteAabb(root));
    }
    return slabs;
  }
}

class KinematicConfig {
  final double gravity;
  final double gravityScale;
  final double maxFallSpeed;
  final double maxHorizontalSpeed;
  final double maxStepSize;
  final bool applyGravity;
  final bool enableHorizontal;
  final bool enableVertical;
  final bool startOnGround;

  /// false のとき床スラブへの足スナップを行わない（地表からの掘削進入用）
  final bool enableFootSnap;

  const KinematicConfig({
    this.gravity = KinematicMovement.defaultGravity,
    this.gravityScale = 1.0,
    this.maxFallSpeed = 1200,
    this.maxHorizontalSpeed = 800,
    this.maxStepSize = KinematicMovement.defaultMaxStep,
    this.applyGravity = true,
    this.enableHorizontal = true,
    this.enableVertical = true,
    this.startOnGround = false,
    this.enableFootSnap = true,
  });
}

class KinematicMoveResult {
  final bool isOnGround;
  final bool hitCeiling;
  final bool hitWall;

  const KinematicMoveResult({
    required this.isOnGround,
    this.hitCeiling = false,
    this.hitWall = false,
  });
}
