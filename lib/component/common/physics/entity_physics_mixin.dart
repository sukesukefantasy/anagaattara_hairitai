import 'dart:math';
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
  static const double kGravity = 700.0;
  static const double _kGravity = kGravity;

  double gravityScale = 1.0;
  double maxFallSpeed = 1200.0;
  double maxHorizontalSpeed = 800.0;
  Vector2 velocity = Vector2.zero();

  /// 歩行・パトロール速度（[preparePhysicsVelocity]）とは別に保持するノックバック成分。
  /// 当たり判定付き移動の導入後も、被弾時の押し出しを維持するため。
  Vector2 knockbackVelocity = Vector2.zero();

  bool isOnGround = false;
  double stepOverBasisSpeed = 180.0;

  final Set<PositionComponent> _solidCollisions = {};
  final Set<PositionComponent> _ignoredHorizontalSolidRoots = {};
  final SmallStepState _smallStepState = SmallStepState();

  bool get isPhysicsSteppingOver => _smallStepState.lastLiftApplied > 0;

  /// 水平速度を [updatePhysics] の前に設定する（WalkingEnemy / CarEnemy 用）。
  @protected
  void preparePhysicsVelocity(double dt) {}

  /// 被弾・衝突などのノックバック（[preparePhysicsVelocity] とは独立）。
  @protected
  void applyKnockbackImpulse(Vector2 impulse, {double mass = 1.0}) {
    knockbackVelocity.add(impulse / mass);
  }

  void _decayKnockback(double dt) {
    knockbackVelocity.x *= max(0.0, 1.0 - 5.0 * dt);
    if (knockbackVelocity.x.abs() < 2.0) {
      knockbackVelocity.x = 0.0;
    }
    knockbackVelocity.y *= max(0.0, 1.0 - 3.0 * dt);
    if (knockbackVelocity.y.abs() < 2.0) {
      knockbackVelocity.y = 0.0;
    }
  }

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

    // 歩行速度 + ノックバックを合成して当たり判定付き移動する。
    final physicsVelocity = velocity.clone()..add(knockbackVelocity);

    final result = KinematicMovement.integrate(
      body: this,
      velocity: physicsVelocity,
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

    // 垂直成分のみ [velocity] に反映（水平は次フレームの preparePhysicsVelocity が担当）。
    velocity.y = physicsVelocity.y;
    if (result.hitWall) {
      knockbackVelocity.x = 0;
    }
    if (result.hitCeiling && knockbackVelocity.y < 0) {
      knockbackVelocity.y = 0;
    }

    isOnGround = result.isOnGround;
    _decayKnockback(dt);
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

/// [Item] 向け: 地下床板 slab と投擲速度（水平・垂直）を扱う物理。
mixin ItemPhysicsMixin on EntityPhysicsMixin {
  @override
  void updatePhysics(double dt) {
    SmallStepTraversal.endFrame(
      _smallStepState,
      _ignoredHorizontalSolidRoots,
    );

    _solidCollisions.removeWhere((s) => !s.isMounted);
    _ignoredHorizontalSolidRoots.removeWhere((s) => !s.isMounted);

    preparePhysicsVelocity(dt);

    final gameRef = findGame();
    final outdoor = gameRef is MyGame
        ? gameRef.sceneManager.currentScene
        : null;
    final outdoorScene =
        outdoor is AbstractOutdoorScene ? outdoor : null;

    Rect? groundSlabRect;
    if (outdoorScene?.ground != null) {
      groundSlabRect = PhysicsStepQueries.absoluteAabb(outdoorScene!.ground!);
    }

    final slabs = <Rect>[];
    final floorSlabList = <Rect>[];
    final ug = outdoorScene?.underGround;
    if (ug != null) {
      _solidCollisions.remove(ug);
    }
    for (final raw in _solidCollisions) {
      if (!raw.isMounted) continue;
      final root = PhysicsStepQueries.solidRoot(
        raw is ShapeHitbox ? raw.parent! as PositionComponent : raw,
      );
      if (_ignoredHorizontalSolidRoots.contains(root)) continue;
      if (ug != null && identical(root, ug)) continue;
      slabs.addAll(KinematicMovement.collectTerrainSlabs([raw]));
    }

    if (outdoorScene != null && groundSlabRect != null) {
      slabs.add(groundSlabRect);
    }

    if (ug != null) {
      floorSlabList.addAll(ug.floorSlabs());
      slabs.addAll(floorSlabList);
    }

    final terrain = outdoorScene?.underGround.terrainField;

    final physicsVelocity = velocity.clone()..add(knockbackVelocity);

    final result = KinematicMovement.integrate(
      body: this,
      velocity: physicsVelocity,
      dt: dt,
      config: KinematicConfig(
        gravity: EntityPhysicsMixin.kGravity,
        gravityScale: gravityScale,
        maxFallSpeed: maxFallSpeed,
        maxHorizontalSpeed: maxHorizontalSpeed,
        applyGravity: !isOnGround,
        startOnGround: isOnGround,
      ),
      terrain: terrain,
      staticSlabs: slabs,
      preferredFootSlabs: floorSlabList,
      oneWaySlabs: floorSlabList,
    );

    velocity = physicsVelocity;
    if (result.hitWall) {
      knockbackVelocity.x = 0;
    }
    if (result.hitCeiling && knockbackVelocity.y < 0) {
      knockbackVelocity.y = 0;
    }

    isOnGround = result.isOnGround;
    _decayKnockback(dt);
  }
}

/// プレイヤー接触ノックバックの力積源（p = mass × velocity）。
mixin ContactKnockbackSource on PositionComponent {
  double get contactMass;

  Vector2 get contactVelocity;

  /// ほぼ静止接触時の退避方向（正=右）。
  double get contactFallbackDirectionX => -1.0;
}
