import 'dart:ui' show Offset, Rect;

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';

import '../terrain/terrain_field.dart';
import 'physics_body_queries.dart';
import 'physics_step_obstacle.dart';

/// 小段差乗り越えの状態（プレイヤー／敵ごとに1つ保持）。
class SmallStepState {
  /// 直近フレームで段差処理したか（アニメ用。即時処理のため active は使わない）
  double lastLiftApplied = 0;
  int lastIntent = 0;

  PositionComponent? obstacleRootPendingUnignore;
}

/// [size.y / 2] 以下の段差を乗り越える共通 API（将来アニメ差し替え用）。
abstract final class SmallStepTraversal {
  static const double stepForwardPx = 6.0;
  static const double liftProbeStepPx = 4.0;
  static const double surfaceClearancePx = 2.0;

  static double maxStepHeight(PositionComponent body) => body.size.y / 2;

  /// 即時 [position] 調整で段差を乗り越える。成功時 true。
  static bool tryBegin({
    required SmallStepState state,
    required PositionComponent body,
    required int intent,
    required Iterable<PositionComponent> solidCandidates,
    required Set<PositionComponent> ignoredHorizontalRoots,
    required Vector2 velocity,
    required double basisSpeed,
    TerrainField? terrain,
    double horizontalDxAttempt = 0,
  }) {
    if (intent == 0) return false;

    _flushPendingUnignore(state, ignoredHorizontalRoots);

    final obstacle = _findObstacle(
      body: body,
      intent: intent,
      solidCandidates: solidCandidates,
      ignoredHorizontalRoots: ignoredHorizontalRoots,
      horizontalDxAttempt: horizontalDxAttempt,
    );
    if (obstacle != null && obstacle is PhysicsStepObstacleMixin) {
      return _applyObstacleStep(
        state: state,
        body: body,
        intent: intent,
        obstacle: obstacle,
        ignoredHorizontalRoots: ignoredHorizontalRoots,
        velocity: velocity,
      );
    }

    if (terrain != null) {
      return _applyTerrainLedgeStep(
        state: state,
        body: body,
        terrain: terrain,
        intent: intent,
        velocity: velocity,
      );
    }
    return false;
  }

  /// フレーム終了時に呼ぶ（障害物 ignore の解放）。
  static void endFrame(SmallStepState state, Set<PositionComponent> ignoredHorizontalRoots) {
    _flushPendingUnignore(state, ignoredHorizontalRoots);
    state.lastLiftApplied = 0;
  }

  static void _flushPendingUnignore(
    SmallStepState state,
    Set<PositionComponent> ignoredHorizontalRoots,
  ) {
    final pending = state.obstacleRootPendingUnignore;
    if (pending != null) {
      ignoredHorizontalRoots.remove(pending);
      state.obstacleRootPendingUnignore = null;
    }
  }

  static bool _applyObstacleStep({
    required SmallStepState state,
    required PositionComponent body,
    required int intent,
    required PositionComponent obstacle,
    required Set<PositionComponent> ignoredHorizontalRoots,
    required Vector2 velocity,
  }) {
    final obs = obstacle as PhysicsStepObstacleMixin;
    final aabb = PhysicsBodyQueries.physicsAabb(body);
    final maxLift = maxStepHeight(body);
    final needed =
        obs.physicsStepSurfaceTopWorldY - aabb.bottom + surfaceClearancePx;
    final lift = needed.clamp(0.0, maxLift);
    if (lift < 1e-3) return false;

    body.position.y -= lift;
    body.position.x += intent * stepForwardPx;
    velocity.y = 0;

    ignoredHorizontalRoots.add(obstacle);
    state.obstacleRootPendingUnignore = obstacle;
    state.lastLiftApplied = lift;
    state.lastIntent = intent;
    return true;
  }

  static bool _applyTerrainLedgeStep({
    required SmallStepState state,
    required PositionComponent body,
    required TerrainField terrain,
    required int intent,
    required Vector2 velocity,
  }) {
    final lift = _findSafeTerrainLift(body: body, terrain: terrain, intent: intent);
    if (lift == null) return false;

    body.position.y -= lift;
    body.position.x += intent * stepForwardPx;
    velocity.y = 0;

    state.lastLiftApplied = lift;
    state.lastIntent = intent;
    return true;
  }

  static double? _findSafeTerrainLift({
    required PositionComponent body,
    required TerrainField terrain,
    required int intent,
  }) {
    final aabb = PhysicsBodyQueries.physicsAabb(body);
    final shifted = Rect.fromLTRB(
      aabb.left + intent * liftProbeStepPx,
      aabb.top,
      aabb.right + intent * liftProbeStepPx,
      aabb.bottom,
    );
    if (!terrain.isBlocked(shifted)) return null;

    final maxLift = maxStepHeight(body);
    for (var lift = liftProbeStepPx; lift <= maxLift; lift += liftProbeStepPx) {
      final liftedBody = shifted.shift(Offset(0, -lift));
      if (terrain.isBlocked(liftedBody)) continue;

      final forward = liftedBody.shift(Offset(intent * liftProbeStepPx, 0));
      if (!terrain.isBlocked(forward)) {
        return lift;
      }
    }
    return null;
  }

  static PositionComponent? _findObstacle({
    required PositionComponent body,
    required int intent,
    required Iterable<PositionComponent> solidCandidates,
    required Set<PositionComponent> ignoredHorizontalRoots,
    required double horizontalDxAttempt,
  }) {
    final base = PhysicsBodyQueries.physicsAabb(body);
    final probeDx =
        horizontalDxAttempt.abs() > 1e-6 ? horizontalDxAttempt : intent * liftProbeStepPx;
    final shifted = Rect.fromLTRB(
      base.left + probeDx,
      base.top,
      base.right + probeDx,
      base.bottom,
    );

    for (final raw in solidCandidates) {
      if (!raw.isMounted) continue;
      final root = PhysicsStepQueries.solidRoot(
        raw is ShapeHitbox ? raw.parent! as PositionComponent : raw,
      );
      if (ignoredHorizontalRoots.contains(root)) continue;
      if (root is! PhysicsStepObstacleMixin) continue;
      if (root.physicsStepClearHeight > maxStepHeight(body)) continue;

      final solidRect = PhysicsStepQueries.absoluteAabb(root);
      if (!shifted.overlaps(solidRect)) continue;

      final ox = PhysicsStepQueries.axisOverlap(
        shifted.left,
        shifted.right,
        solidRect.left,
        solidRect.right,
      );
      final oy = PhysicsStepQueries.axisOverlap(
        shifted.top,
        shifted.bottom,
        solidRect.top,
        solidRect.bottom,
      );
      if (ox <= 0 || oy <= 0 || ox >= oy) continue;

      final towardWall = solidRect.center.dx >= shifted.center.dx ? 1 : -1;
      if (intent != towardWall) continue;

      return root;
    }
    return null;
  }
}
