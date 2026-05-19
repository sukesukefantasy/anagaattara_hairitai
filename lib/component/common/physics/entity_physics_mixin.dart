import 'dart:ui' show Rect;

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/foundation.dart';

import '../../../main.dart';
import '../../../scene/abstract_outdoor_scene.dart';
import '../collision/collision_family.dart';
import '../terrain/terrain_field.dart';
import 'kinematic_movement.dart';
import 'physics_step_obstacle.dart';
import 'small_step_traversal.dart';

/// 運動学スイープ＋サブステップによる物理ミックスイン。
///
/// EnemyBase・Npc などに mix in し、重力・着地・壁抜け防止を提供する。
mixin EntityPhysicsMixin on PositionComponent, CollisionCallbacks {
  static const double _kGravity = 700.0;

  double gravityScale = 1.0;
  double maxFallSpeed = 1200.0;
  double maxHorizontalSpeed = 800.0;
  Vector2 velocity = Vector2.zero();
  bool isOnGround = false;
  double stepOverBasisSpeed = 180.0;

  final Set<PositionComponent> _solidCollisions = {};
  final Set<PositionComponent> _ignoredHorizontalSolidRoots = {};
  final SmallStepState _smallStepState = SmallStepState();

  bool get isPhysicsSteppingOver => _smallStepState.lastLiftApplied > 0;

  /// 水平速度を [updatePhysics] の前に設定する（WalkingEnemy / CarEnemy 用）。
  @protected
  void preparePhysicsVelocity(double dt) {}

  void updatePhysics(double dt) {
    SmallStepTraversal.endFrame(
      _smallStepState,
      _ignoredHorizontalSolidRoots,
    );

    _solidCollisions.removeWhere((s) => !s.isMounted);
    _ignoredHorizontalSolidRoots.removeWhere((s) => !s.isMounted);

    preparePhysicsVelocity(dt);

    final slabs = <Rect>[
      ..._collectSlabsExcludingIgnored(),
      if (_outdoorGroundSlab() case final g?) g,
    ];

    final terrain = _outdoorTerrainField();

    final result = KinematicMovement.integrate(
      body: this,
      velocity: velocity,
      dt: dt,
      config: KinematicConfig(
        gravity: _kGravity,
        gravityScale: gravityScale,
        maxFallSpeed: maxFallSpeed,
        maxHorizontalSpeed: maxHorizontalSpeed,
        applyGravity: !isOnGround,
        startOnGround: isOnGround,
      ),
      terrain: terrain,
      staticSlabs: slabs,
    );

    isOnGround = result.isOnGround;
    _tryResolveStepOverAfterMove(terrain: terrain);
  }

  int get stepOverHorizontalIntent {
    if (velocity.x.abs() > 2.0) {
      return velocity.x.sign.toInt();
    }
    return 0;
  }

  void _tryResolveStepOverAfterMove({TerrainField? terrain}) {
    final intent = stepOverHorizontalIntent;
    if (intent == 0 || !isOnGround) return;

    SmallStepTraversal.tryBegin(
      state: _smallStepState,
      body: this,
      intent: intent,
      solidCandidates: _solidCollisions,
      ignoredHorizontalRoots: _ignoredHorizontalSolidRoots,
      velocity: velocity,
      basisSpeed: stepOverBasisSpeed,
      terrain: terrain,
    );
  }

  Iterable<Rect> _collectSlabsExcludingIgnored() sync* {
    for (final raw in _solidCollisions) {
      if (!raw.isMounted) continue;
      final root = PhysicsStepQueries.solidRoot(
        raw is ShapeHitbox ? raw.parent! as PositionComponent : raw,
      );
      if (_ignoredHorizontalSolidRoots.contains(root)) continue;
      yield* KinematicMovement.collectTerrainSlabs([raw]);
    }
  }

  TerrainField? _outdoorTerrainField() {
    final gameRef = findGame();
    if (gameRef is! MyGame) return null;
    final scene = gameRef.sceneManager.currentScene;
    if (scene is AbstractOutdoorScene) {
      return scene.underGround.terrainField;
    }
    return null;
  }

  Rect? _outdoorGroundSlab() {
    final gameRef = findGame();
    if (gameRef is! MyGame) return null;
    final scene = gameRef.sceneManager.currentScene;
    if (scene is AbstractOutdoorScene && scene.ground != null) {
      return PhysicsStepQueries.absoluteAabb(scene.ground!);
    }
    return null;
  }

  @override
  void onCollisionStart(
    Set<Vector2> intersectionPoints,
    PositionComponent other,
  ) {
    super.onCollisionStart(intersectionPoints, other);
    if (_isPhysicsSolid(other)) {
      _solidCollisions.add(other);
    }
  }

  @override
  void onCollisionEnd(PositionComponent other) {
    super.onCollisionEnd(other);
    _solidCollisions.remove(other);
  }

  static bool _isPhysicsSolid(PositionComponent c) {
    if (c is EntityPhysicsMixin) return false;
    if (c is ShapeHitbox) {
      if (c.parent is EntityPhysicsMixin) return false;
      if (collisionFamilyOf(c) == CollisionFamily.prop) return false;
      return c.isSolid;
    }
    return c.children.whereType<ShapeHitbox>().any((h) => h.isSolid);
  }

  @override
  void onMount() {
    super.onMount();
    debugPrint('[EntityPhysicsMixin] mounted: $runtimeType');
  }
}
