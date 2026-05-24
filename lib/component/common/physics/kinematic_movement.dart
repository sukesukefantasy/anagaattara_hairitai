import 'dart:math';
import 'dart:ui' show Rect;

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';

import '../collision/collision_family.dart';
import '../terrain/terrain_collision_samples.dart';
import '../terrain/terrain_field.dart';
import 'physics_body_queries.dart';
import 'physics_step_obstacle.dart';
import 'small_step_traversal.dart';

/// サブステップ＋軸分離スイープによる運動学移動（トンネリング防止）。
class KinematicMovement {
  static const double defaultMaxStep = 16.0;
  static const double defaultGravity = 700.0;

  /// 物理用 dt の上限（秒）。レンダー dt が大きくても1ステップの移動量を抑える。
  static const double maxPhysicsDt = 1.0 / 30.0;

  static double clampPhysicsDt(double dt) => min(dt, maxPhysicsDt);

  static bool _isStationary(Vector2 velocity) =>
      velocity.x.abs() <= 1 && velocity.y.abs() <= 10;

  /// 設置床など、上から下へ抜けられる／下から中心で乗り上がるワンウェイ slab。
  static const double oneWaySlabFootSnapPenPx = 14.0;
  static const double oneWaySlabHorizontalStepPx = 6.0;

  static KinematicMoveResult integrate({
    required PositionComponent body,
    required Vector2 velocity,
    required double dt,
    required KinematicConfig config,
    TerrainField? terrain,
    List<Rect> staticSlabs = const [],
    List<Rect> preferredFootSlabs = const [],
    List<Rect> oneWaySlabs = const [],
    bool dropThroughOneWaySlabs = false,
    void Function(Vector2 previousWorld, Vector2 newWorld)? onPositionApplied,
  }) {
    dt = clampPhysicsDt(dt);
    velocity.x = velocity.x.clamp(-config.maxHorizontalSpeed, config.maxHorizontalSpeed);

    var isOnGround = config.startOnGround;
    var hitCeiling = false;
    var hitWall = false;

    final bodyAabb = PhysicsBodyQueries.physicsAabb(body);
    final onPreferredFloor = preferredFootSlabs.isNotEmpty &&
        _feetRestingOnSlab(bodyAabb, preferredFootSlabs);

    if (dropThroughOneWaySlabs) {
      isOnGround = false;
      _nudgeThroughOneWaySlabs(
        body: body,
        oneWaySlabs: oneWaySlabs,
        velocity: velocity,
      );
    } else if (onPreferredFloor) {
      isOnGround = true;
    }

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
          oneWaySlabs: oneWaySlabs,
          dropThroughOneWaySlabs: dropThroughOneWaySlabs,
          config: config,
          velocity: velocity,
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
          oneWaySlabs: oneWaySlabs,
          dropThroughOneWaySlabs: dropThroughOneWaySlabs,
          config: config,
          velocity: velocity,
        );
        if (step.y < 0 && oneWaySlabs.isNotEmpty) {
          _tryPromoteOntoOneWaySlab(
            body: body,
            velocity: velocity,
            oneWaySlabs: oneWaySlabs,
          );
        }
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

    if (terrain != null) {
      final onPlacedFloor = !dropThroughOneWaySlabs &&
          preferredFootSlabs.isNotEmpty &&
          _feetRestingOnSlab(PhysicsBodyQueries.physicsAabb(body), preferredFootSlabs);
      if (!onPlacedFloor) {
        _assistUphillTerrain(
          body: body,
          terrain: terrain,
          velocity: velocity,
        );
        _clampCornersToPassable(
          body: body,
          terrain: terrain,
          velocity: velocity,
        );
      }
    }

    _resolveHeadPenetration(
      body: body,
      terrain: terrain,
      staticSlabs: staticSlabs,
      oneWaySlabs: oneWaySlabs,
      dropThroughOneWaySlabs: dropThroughOneWaySlabs,
      velocity: velocity,
    );

    if (config.enableFootSnap) {
      final snapped = _snapFeetOntoSlabs(
        body: body,
        velocity: velocity,
        staticSlabs: staticSlabs,
        oneWaySlabs: oneWaySlabs,
        dropThroughOneWaySlabs: dropThroughOneWaySlabs,
        isOnGround: isOnGround,
      );
      isOnGround = snapped || isOnGround;

      final onPlacedFloor = !dropThroughOneWaySlabs &&
          preferredFootSlabs.isNotEmpty &&
          _feetRestingOnSlab(PhysicsBodyQueries.physicsAabb(body), preferredFootSlabs);

      if (terrain != null && !onPlacedFloor) {
        isOnGround = _snapFeetOntoTerrain(
              body: body,
              terrain: terrain,
              velocity: velocity,
              isOnGround: isOnGround,
            ) ||
            isOnGround;
      }
      if (onPlacedFloor) {
        isOnGround = true;
      } else if (terrain != null) {
        isOnGround = _feetOnTerrain(
              terrain,
              PhysicsBodyQueries.physicsAabb(body),
            ) ||
            isOnGround;
      }
    }

    return KinematicMoveResult(
      isOnGround: isOnGround,
      hitCeiling: hitCeiling,
      hitWall: hitWall,
    );
  }

  /// 落下は足元のみ。上昇は頭プローブのみ（胴のめり込みは許容）。
  static bool _isBlockedVertical(TerrainField terrain, Rect after, double delta) {
    if (delta < 0) {
      return TerrainCollisionSamples.isHeadBlocked(
        after,
        (probe) => terrain.isBlocked(probe),
      );
    }
    for (final p in TerrainCollisionSamples.verticalDownProbePoints(after)) {
      if (terrain.isBlocked(TerrainCollisionSamples.probeRect(p))) {
        return true;
      }
    }
    return false;
  }

  /// 足元から下方向に probe し、岩面 Y（上面）を返す。
  static double? _terrainSurfaceYAt(
    TerrainField terrain,
    double x,
    double footBottom, {
    double maxProbe = 36,
  }) {
    for (var dy = 0.0; dy <= maxProbe; dy += 2) {
      final probeY = footBottom + dy;
      if (terrain.isBlocked(
        TerrainCollisionSamples.probeRect(Vector2(x, probeY)),
      )) {
        return probeY - 2;
      }
    }
    return null;
  }

  /// 横移動時、前方の高い床面へ先読みリフト（四隅 clamp の補助）。
  static void _assistUphillTerrain({
    required PositionComponent body,
    required TerrainField terrain,
    required Vector2 velocity,
  }) {
    if (velocity.x.abs() <= 1) return;
    if (velocity.y > 48) return;

    const aheadPx = 10.0;
    const maxUphillLiftPerFrame = 12.0;
    final intent = velocity.x.sign;
    final mine = PhysicsBodyQueries.physicsAabb(body);
    final footBottom = mine.bottom;

    double? targetSurfaceY;
    for (final x in [
      mine.center.dx,
      mine.left + mine.width * 0.2,
      mine.right - mine.width * 0.2,
      mine.center.dx + intent * aheadPx,
      mine.left + mine.width * 0.2 + intent * aheadPx,
      mine.right - mine.width * 0.2 + intent * aheadPx,
    ]) {
      final surfaceY = _terrainSurfaceYAt(terrain, x, footBottom);
      if (surfaceY != null) {
        targetSurfaceY =
            targetSurfaceY == null ? surfaceY : min(targetSurfaceY, surfaceY);
      }
    }

    if (targetSurfaceY == null) return;
    final lift = footBottom - targetSurfaceY;
    if (lift > 0.5 && lift <= maxUphillLiftPerFrame) {
      body.position.y -= lift;
      if (velocity.y > 2) velocity.y = 0;
    }
  }

  /// 足元プローブのいずれかが岩（床接触）なら true。
  static bool _feetOnTerrain(TerrainField terrain, Rect aabb) {
    for (final p in TerrainCollisionSamples.verticalDownProbePoints(aabb)) {
      if (terrain.isBlocked(TerrainCollisionSamples.probeRect(p))) {
        return true;
      }
    }
    return false;
  }

  /// 四隅＋中心が通行可能領域内になるまで位置を補正。
  static void _clampCornersToPassable({
    required PositionComponent body,
    required TerrainField terrain,
    required Vector2 velocity,
    double maxCorrection = 16,
  }) {
    if (_isStationary(velocity)) return;

    final stationary = velocity.x.abs() <= 1;
    final maxDown = stationary ? 4.0 : maxCorrection;
    var corrected = 0.0;

    while (corrected < maxCorrection &&
        terrain.isBlocked(PhysicsBodyQueries.physicsAabb(body))) {
      final savedY = body.position.y;
      final savedX = body.position.x;

      body.position.y -= 1;
      if (!terrain.isBlocked(PhysicsBodyQueries.physicsAabb(body))) {
        corrected += 1;
        continue;
      }
      body.position.y = savedY;

      if (corrected < maxDown) {
        body.position.y += 1;
        if (!terrain.isBlocked(PhysicsBodyQueries.physicsAabb(body))) {
          corrected += 1;
          continue;
        }
        body.position.y = savedY;
      }

      if (velocity.x.abs() > 1) {
        body.position.x -= velocity.x.sign.toDouble();
        if (!terrain.isBlocked(PhysicsBodyQueries.physicsAabb(body))) {
          corrected += 1;
          continue;
        }
        body.position.x = savedX;
      }

      break;
    }
  }

  /// 頭だけ岩／スラブから軽く押し出す（狭い下り坂の追従用。下方向は控えめ）。
  static void _resolveHeadPenetration({
    required PositionComponent body,
    required TerrainField? terrain,
    required List<Rect> staticSlabs,
    required List<Rect> oneWaySlabs,
    required bool dropThroughOneWaySlabs,
    required Vector2 velocity,
  }) {
    if (dropThroughOneWaySlabs) return;
    if (_isStationary(velocity) && terrain != null) return;

    const maxPushDown = 4.0;
    const step = 1.0;
    var pushed = 0.0;

    while (pushed < maxPushDown &&
        _isHeadPenetrating(
          PhysicsBodyQueries.physicsAabb(body),
          terrain: terrain,
          staticSlabs: staticSlabs,
          oneWaySlabs: oneWaySlabs,
          dropThroughOneWaySlabs: dropThroughOneWaySlabs,
          velocity: velocity,
        )) {
      body.position.y += step;
      pushed += step;
    }
  }

  static bool _isHeadPenetrating(
    Rect aabb, {
    required TerrainField? terrain,
    required List<Rect> staticSlabs,
    required List<Rect> oneWaySlabs,
    required bool dropThroughOneWaySlabs,
    required Vector2 velocity,
  }) {
    for (final p in TerrainCollisionSamples.headProbePoints(aabb)) {
      final probe = TerrainCollisionSamples.probeRect(p);
      if (terrain != null && terrain.isBlocked(probe)) {
        return true;
      }
      for (final slab in staticSlabs) {
        if (!probe.overlaps(slab)) continue;
        if (_ignoreOneWaySlabCollision(
          aabb: aabb,
          slab: slab,
          oneWaySlabs: oneWaySlabs,
          dropThroughOneWaySlabs: dropThroughOneWaySlabs,
          verticalSign: velocity.y.sign,
        )) {
          continue;
        }
        return true;
      }
    }
    return false;
  }

  /// 足元直下の岩面へ軽くスナップ（坂道の接地を安定させる）。
  static bool _snapFeetOntoTerrain({
    required PositionComponent body,
    required TerrainField terrain,
    required Vector2 velocity,
    required bool isOnGround,
  }) {
    if (velocity.x == 0) return isOnGround;
    if (velocity.y < -120) return isOnGround;

    final mine = PhysicsBodyQueries.physicsAabb(body);
    const maxSnap = 28.0;
    double? bestSurfaceY;

    for (final x in [
      mine.center.dx,
      mine.left + mine.width * 0.2,
      mine.right - mine.width * 0.2,
    ]) {
      final surfaceY = _terrainSurfaceYAt(terrain, x, mine.bottom, maxProbe: maxSnap + 8);
      if (surfaceY != null) {
        bestSurfaceY =
            bestSurfaceY == null ? surfaceY : min(bestSurfaceY, surfaceY);
      }
    }

    if (bestSurfaceY == null) return isOnGround;
    final drift = mine.bottom - bestSurfaceY;
    if (drift > 0.5 && drift < maxSnap) {
      body.position.y -= drift;
      if (velocity.y > 2) velocity.y = 0;
      return true;
    }
    return isOnGround;
  }

  static double _moveAxis({
    required PositionComponent body,
    required double delta,
    required bool horizontal,
    required TerrainField? terrain,
    required List<Rect> staticSlabs,
    required List<Rect> oneWaySlabs,
    required bool dropThroughOneWaySlabs,
    required KinematicConfig config,
    Vector2? velocity,
  }) {
    var moved = 0.0;
    var remaining = delta.abs();
    final sign = delta.sign;

    while (remaining > 1e-6) {
      final chunk = min(remaining, config.maxStepSize) * sign;
      final before = PhysicsBodyQueries.physicsAabb(body);
      body.position += horizontal ? Vector2(chunk, 0) : Vector2(0, chunk);
      var after = PhysicsBodyQueries.physicsAabb(body);
      var yLiftApplied = 0.0;
      var blocked = false;

      if (terrain != null) {
        if (horizontal) {
          if (terrain.isBlocked(after)) {
            final savedY = body.position.y;
            var cleared = false;
            final maxLift = body.size.y / 2;
            for (var lift = 1.0; lift <= maxLift; lift += 1.0) {
              body.position.y -= 1;
              yLiftApplied += 1;
              after = PhysicsBodyQueries.physicsAabb(body);
              if (!terrain.isBlocked(after)) {
                cleared = true;
                if (velocity != null && velocity.y > 0) velocity.y = 0;
                break;
              }
            }
            if (!cleared) {
              body.position.y = savedY;
              body.position.x -= chunk;
              yLiftApplied = 0;
              after = PhysicsBodyQueries.physicsAabb(body);
              blocked = true;
            }
          }
        } else if (_isBlockedVertical(terrain, after, delta)) {
          body.position.y -= chunk;
          blocked = true;
        }
      }

      if (blocked) break;

      final blockingSlab = _findBlockingSlab(
        after,
        staticSlabs,
        horizontal,
        sign,
        before,
        oneWaySlabs: oneWaySlabs,
        dropThroughOneWaySlabs: dropThroughOneWaySlabs,
      );
      if (blockingSlab != null) {
        if (horizontal &&
            _isOneWaySlab(blockingSlab, oneWaySlabs) &&
            _tryStepOntoOneWaySlab(
              body: body,
              slab: blockingSlab,
              intent: sign.toInt(),
              velocity: velocity,
            )) {
          moved += chunk;
          remaining -= chunk.abs();
          continue;
        }
        body.position.x -= horizontal ? chunk : 0;
        body.position.y -= horizontal ? 0 : chunk;
        if (yLiftApplied > 0) body.position.y += yLiftApplied;
        break;
      }

      moved += chunk;
      remaining -= chunk.abs();
    }
    return moved;
  }

  static Rect? _findBlockingSlab(
    Rect aabb,
    List<Rect> slabs,
    bool horizontal,
    double sign,
    Rect before, {
    required List<Rect> oneWaySlabs,
    required bool dropThroughOneWaySlabs,
  }) {
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

      if (_ignoreOneWaySlabCollision(
        aabb: before,
        slab: slab,
        oneWaySlabs: oneWaySlabs,
        dropThroughOneWaySlabs: dropThroughOneWaySlabs,
        verticalSign: horizontal ? 0 : sign,
      )) {
        continue;
      }

      if (horizontal) {
        if (ox >= oy) continue;
        final towardWall = slab.center.dx >= before.center.dx ? 1.0 : -1.0;
        if (sign == towardWall) return slab;
      } else {
        if (oy > ox) continue;
        if (sign > 0 && aabb.bottom > slab.top + 0.5) {
          // 落下で床に当たった
          if (aabb.center.dy >= slab.top) return slab;
        }
        if (sign < 0) {
          if (_isOneWaySlab(slab, oneWaySlabs) &&
              before.center.dy > slab.top + 0.5) {
            continue;
          }
          for (final p in TerrainCollisionSamples.headProbePoints(aabb)) {
            if (TerrainCollisionSamples.probeRect(p).overlaps(slab)) {
              return slab;
            }
          }
        }
      }
    }
    return null;
  }

  /// 下から上へ: 中心が床上面に達したら上面へスワップ。
  static void _tryPromoteOntoOneWaySlab({
    required PositionComponent body,
    required Vector2 velocity,
    required List<Rect> oneWaySlabs,
  }) {
    if (velocity.y >= -1) return;

    final aabb = PhysicsBodyQueries.physicsAabb(body);
    for (final slab in oneWaySlabs) {
      final ox = PhysicsStepQueries.axisOverlap(
        aabb.left,
        aabb.right,
        slab.left,
        slab.right,
      );
      if (ox <= 0 || !aabb.overlaps(slab)) continue;
      if (aabb.center.dy > slab.top + 0.5) continue;

      final drift = aabb.bottom - slab.top;
      if (drift <= 0.5) {
        velocity.y = 0;
        return;
      }
      body.position.y -= drift;
      velocity.y = 0;
      return;
    }
  }

  /// 目の前のワンウェイ床への小段差乗り上げ（SmallStep と同等の即時リフト）。
  static bool _tryStepOntoOneWaySlab({
    required PositionComponent body,
    required Rect slab,
    required int intent,
    Vector2? velocity,
  }) {
    if (intent == 0) return false;

    final aabb = PhysicsBodyQueries.physicsAabb(body);
    final maxLift = body.size.y / 2;
    final needed =
        slab.top - aabb.bottom + SmallStepTraversal.surfaceClearancePx;
    final lift = needed.clamp(0.0, maxLift);
    if (lift < 1e-3) return false;

    body.position.y -= lift;
    body.position.x += intent * oneWaySlabHorizontalStepPx;
    velocity?.y = 0;
    return true;
  }

  static bool _isOneWaySlab(Rect slab, List<Rect> oneWaySlabs) {
    for (final candidate in oneWaySlabs) {
      if (_slabsMatch(slab, candidate)) return true;
    }
    return false;
  }

  static bool _slabsMatch(Rect a, Rect b) {
    const eps = 0.5;
    return (a.left - b.left).abs() <= eps &&
        (a.top - b.top).abs() <= eps &&
        (a.right - b.right).abs() <= eps &&
        (a.bottom - b.bottom).abs() <= eps;
  }

  /// しゃがみ開始時: 足元が載っているワンウェイ床を1フレームで下面まで抜ける。
  static void _nudgeThroughOneWaySlabs({
    required PositionComponent body,
    required List<Rect> oneWaySlabs,
    required Vector2 velocity,
  }) {
    final aabb = PhysicsBodyQueries.physicsAabb(body);
    for (final slab in oneWaySlabs) {
      if (!_feetRestingOnSlab(aabb, [slab])) continue;

      final targetBottom = slab.bottom + SmallStepTraversal.surfaceClearancePx;
      final delta = targetBottom - aabb.bottom;
      if (delta > 0.5) {
        body.position.y += delta;
      }
      velocity.y = max(velocity.y, 180);
      return;
    }
  }

  static bool _ignoreOneWaySlabCollision({
    required Rect aabb,
    required Rect slab,
    required List<Rect> oneWaySlabs,
    required bool dropThroughOneWaySlabs,
    required double verticalSign,
  }) {
    if (!_isOneWaySlab(slab, oneWaySlabs)) return false;

    if (dropThroughOneWaySlabs) {
      return true;
    }
    if (verticalSign < 0 && aabb.center.dy > slab.top + 0.5) {
      return true;
    }
    return false;
  }

  static bool _snapFeetOntoSlabs({
    required PositionComponent body,
    required Vector2 velocity,
    required List<Rect> staticSlabs,
    required List<Rect> oneWaySlabs,
    required bool dropThroughOneWaySlabs,
    required bool isOnGround,
  }) {
    if (velocity.y < -120) return isOnGround;
    if (dropThroughOneWaySlabs) return isOnGround;

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

      final isOneWay = _isOneWaySlab(slab, oneWaySlabs);
      final maxPen = isOneWay
          ? oneWaySlabFootSnapPenPx
          : max(72.0, body.size.y * 0.42) + slab.height * 0.5;
      final pen = mine.bottom - slab.top;
      if (pen < -3 || pen > maxPen) continue;

      // ワンウェイ床: 中心がまだ下面側なら吸着しない（下を通過中）
      if (isOneWay && mine.center.dy > slab.top + 0.5) continue;

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

  /// 設置床板の上面に足が載っているか（地形スナップ競合回避用）。
  static bool _feetRestingOnSlab(Rect aabb, List<Rect> slabs) {
    for (final slab in slabs) {
      final ox = PhysicsStepQueries.axisOverlap(
        aabb.left,
        aabb.right,
        slab.left,
        slab.right,
      );
      if (ox <= 0) continue;
      final pen = aabb.bottom - slab.top;
      if (pen >= -2.5 && pen <= 6) {
        return true;
      }
    }
    return false;
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
      final aabb = PhysicsStepQueries.absoluteAabb(root);
      // 地下コンテナ全体は [TerrainField] が担当（巨大スラブで吸着するのを防ぐ）
      if (aabb.width > 3000 || aabb.height > 900) {
        continue;
      }
      slabs.add(aabb);
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
