import 'dart:math';
import 'dart:ui' show Rect;
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/foundation.dart';

import '../collision/collision_family.dart';
import 'physics_step_obstacle.dart';

/// 軸分離 MTV（最小移動ベクトル）補正による物理ミックスイン。
///
/// EnemyBase・Npc などに mix in し、重力・着地・壁抜け防止を提供する。
/// プレイヤー（独自物理実装）には適用しない。
///
/// 使い方:
///   1. クラス宣言に `EntityPhysicsMixin` を追加（CollisionCallbacks 必須）
///   2. `update(dt)` 内で `updatePhysics(dt)` を呼ぶ
///   3. エンティティの `onLoad()` でフルサイズの物理ヒットボックスを追加する
///
mixin EntityPhysicsMixin on PositionComponent, CollisionCallbacks {
  static const double _kGravity = 700.0;

  /// 重力スケール（0 で無重力、0.5 で軽め）
  double gravityScale = 1.0;

  /// 落下最大速度（ px/s ）
  double maxFallSpeed = 1200.0;

  /// 水平最大速度（トンネリング防止クランプ、px/s）
  double maxHorizontalSpeed = 800.0;

  /// 現在の速度（velocity.x は水平、velocity.y は鉛直; 正が下向き）
  Vector2 velocity = Vector2.zero();

  /// true = 地面または固体の上に立っている
  bool isOnGround = false;

  /// [PhysicsStepObstacleMixin] の段差を登るときの基準速さ（水平→垂直換算に使用）
  double stepOverBasisSpeed = 180.0;

  final Set<PositionComponent> _solidCollisions = {};

  /// 横軸の押し出しを無視するソリッド（乗り越え中）
  final Set<PositionComponent> _ignoredHorizontalSolidRoots = {};

  PositionComponent? _stepOverSolidRoot;
  bool _isSteppingOver = false;

  bool get isPhysicsSteppingOver => _isSteppingOver;

  // ───────────────────────────── 公開 API ─────────────────────────────

  /// `update(double dt)` から毎フレーム呼ぶ。
  /// X軸移動→X補正 → Y軸重力積分→Y補正 の順で処理する。
  void updatePhysics(double dt) {
    if (_isSteppingOver) {
      _stepStepOverClimb(dt);
    } else {
      _stepX(dt);
      _stepY(dt);
    }
    _snapFeetOntoSupportingTerrain();
    _solidCollisions.removeWhere((s) => !s.isMounted);
    _ignoredHorizontalSolidRoots.removeWhere((s) => !s.isMounted);
    if (_stepOverSolidRoot != null && !_stepOverSolidRoot!.isMounted) {
      _endPhysicsStepOver();
    }
  }

  /// 左右入力相当。-1 / 0 / 1。ウォークエネミーなどはオーバーライドする。
  int get stepOverHorizontalIntent {
    if (velocity.x.abs() > 2.0) {
      return velocity.x.sign.toInt();
    }
    return 0;
  }

  // ───────────────────────────── 内部処理 ─────────────────────────────

  void _stepStepOverClimb(double dt) {
    velocity.x = 0;
    velocity.y = -stepOverBasisSpeed * 0.5;
    position.y += velocity.y * dt;
    isOnGround = false;
    _maybeCompletePhysicsStepOver();
  }

  void _stepX(double dt) {
    velocity.x = velocity.x.clamp(-maxHorizontalSpeed, maxHorizontalSpeed);
    position.x += velocity.x * dt;
    _resolveAxis(horizontal: true);
  }

  void _stepY(double dt) {
    if (!isOnGround) {
      velocity.y =
          min(velocity.y + _kGravity * gravityScale * dt, maxFallSpeed);
    }
    position.y += velocity.y * dt;
    isOnGround = false;
    _resolveAxis(horizontal: false);
  }

  void _beginPhysicsStepOver(PositionComponent solidRoot) {
    if (solidRoot is! PhysicsStepObstacleMixin) return;
    _isSteppingOver = true;
    _stepOverSolidRoot = solidRoot;
    _ignoredHorizontalSolidRoots.add(solidRoot);
    velocity.x = 0;
  }

  void _endPhysicsStepOver() {
    _isSteppingOver = false;
    if (_stepOverSolidRoot != null) {
      _ignoredHorizontalSolidRoots.remove(_stepOverSolidRoot);
    }
    _stepOverSolidRoot = null;
  }

  void _maybeCompletePhysicsStepOver() {
    final obs = _stepOverSolidRoot;
    if (obs == null || obs is! PhysicsStepObstacleMixin) {
      _endPhysicsStepOver();
      return;
    }
    final feetBottom = PhysicsStepQueries.absoluteAabb(this).bottom;
    final surfaceY = obs.physicsStepSurfaceTopWorldY;
    if (feetBottom <= surfaceY + 10.0) {
      _endPhysicsStepOver();
    }
  }

  bool _wallCollisionAllowsStepOver({
    required Rect myRect,
    required Rect solidRect,
    required PositionComponent solidRoot,
  }) {
    if (solidRoot is! PhysicsStepObstacleMixin) return false;
    final clearH = solidRoot.physicsStepClearHeight;
    if (clearH > size.y / 2) return false;
    final intent = stepOverHorizontalIntent;
    if (intent == 0) return false;
    if (!isOnGround) return false;

    final towardWall =
        solidRect.center.dx >= myRect.center.dx ? 1 : -1;
    return intent == towardWall;
  }

  /// 各ソリッドとの重なりを解消する。
  /// horizontal=true → X軸壁補正（overlapX が最小軸のときのみ）
  /// horizontal=false → Y軸床/天井補正（overlapY が最小軸のときのみ）
  void _resolveAxis({required bool horizontal}) {
    for (final rawSolid in _solidCollisions.toList()) {
      if (!rawSolid.isMounted) continue;
      final solid = _solidTarget(rawSolid);
      final solidRoot = PhysicsStepQueries.solidRoot(solid);
      final myRect = PhysicsStepQueries.absoluteAabb(this);
      final solidRect = PhysicsStepQueries.absoluteAabb(solidRoot);

      if (!myRect.overlaps(solidRect)) continue;

      final overlapX =
          _calcOverlap(myRect.left, myRect.right, solidRect.left, solidRect.right);
      final overlapY =
          _calcOverlap(myRect.top, myRect.bottom, solidRect.top, solidRect.bottom);

      if (overlapX <= 0 || overlapY <= 0) continue;

      if (horizontal) {
        if (_ignoredHorizontalSolidRoots.contains(solidRoot)) {
          continue;
        }
        // X 補正：overlapX が最小重なり軸（= 壁衝突）のときのみ押し返す
        if (overlapX >= overlapY) continue;
        if (_wallCollisionAllowsStepOver(
              myRect: myRect,
              solidRect: solidRect,
              solidRoot: solidRoot,
            )) {
          _beginPhysicsStepOver(solidRoot);
          continue;
        }
        position.x +=
            myRect.center.dx < solidRect.center.dx ? -overlapX : overlapX;
        velocity.x = 0;
      } else {
        // Y 補正：overlapY が最小重なり軸（= 床/天井）のときのみ押し返す
        if (overlapY > overlapX) continue;
        if (myRect.center.dy <= solidRect.center.dy) {
          // 着地：エンティティ中心がソリッド中心より上 → 押し上げ
          position.y -= overlapY;
          velocity.y = 0;
          isOnGround = true;
        } else {
          // 天井：押し下げ
          position.y += overlapY;
          velocity.y = 0;
        }
      }
    }
  }

  // ───────────────────────── CollisionCallbacks ─────────────────────────

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

  // ─────────────────────────── ヘルパー ───────────────────────────────

  /// 同じ EntityPhysicsMixin を持つコンポーネント（他のエンティティ）は
  /// 物理障害物として扱わない。地形（Ground、壁など）のみを対象とする。
  static bool _isPhysicsSolid(PositionComponent c) {
    if (c is EntityPhysicsMixin) return false;
    if (c is ShapeHitbox) {
      if (c.parent is EntityPhysicsMixin) return false;
      if (collisionFamilyOf(c) == CollisionFamily.prop) return false;
      return c.isSolid;
    }
    return c.children.whereType<ShapeHitbox>().any((h) => h.isSolid);
  }

  /// ヒットボックスが渡された場合は親コンポーネントを使って AABB を計算する。
  static PositionComponent _solidTarget(PositionComponent c) {
    if (c is ShapeHitbox && c.parent is PositionComponent) {
      return c.parent! as PositionComponent;
    }
    return c;
  }

  /// [min, max] と [bMin, bMax] の重なり量を返す（負なら非重なり）。
  static double _calcOverlap(
    double aMin,
    double aMax,
    double bMin,
    double bMax,
  ) =>
      min(aMax, bMax) - max(aMin, bMin);

  /// 地形（Terrain）ヒットボックスに足が食い込んでいる場合、最も高い地面上端へ足元を補正する。
  /// 薄い地面＋ MTV（overlap）判定の組み合わせで縦押し出しが抜けるケースの保険。
  void _snapFeetOntoSupportingTerrain() {
    if (_isSteppingOver) return;
    final mine = PhysicsStepQueries.absoluteAabb(this);

    double? bestTop;
    for (final raw in _solidCollisions) {
      if (!raw.isMounted) continue;
      final solid = _solidTarget(raw);
      final root = PhysicsStepQueries.solidRoot(solid);

      // PositionComponent から HasCollisionFamily への昇格が効かない環境があるため、
      // Object 経由で分岐する。
      final Object rootAny = root;
      final CollisionFamily? family = rootAny is HasCollisionFamily
          ? rootAny.collisionFamily
          : _terrainFamilyHintFromAncestor(root);

      if (family != CollisionFamily.terrain) continue;

      final slab = PhysicsStepQueries.absoluteAabb(root);
      final ox = PhysicsStepQueries.axisOverlap(
        mine.left,
        mine.right,
        slab.left,
        slab.right,
      );
      if (ox <= 0 || !mine.overlaps(slab)) continue;

      final penFromTop = mine.bottom - slab.top;
      if (penFromTop < -3) continue;

      final maxPen = max(
        72.0,
        size.y * 0.42,
      );
      if (penFromTop > maxPen + slab.height * 0.5) continue;

      bestTop = bestTop == null ? slab.top : min(bestTop, slab.top);
    }

    if (bestTop != null && mine.bottom > bestTop && velocity.y >= -120.0) {
      final drift = mine.bottom - bestTop;
      if (drift > 0.5 && drift < 200.0) {
        position.y -= drift;
        if (velocity.y > 2.0) {
          velocity.y = 0;
        }
        isOnGround = true;
      }
    }
  }

  /// 子のみ ShapeHitbox を持つルートで [HasCollisionFamily] が無い場合のヒント。
  static CollisionFamily? _terrainFamilyHintFromAncestor(
    PositionComponent root,
  ) {
    ShapeHitbox? pick;
    for (final child in root.children.whereType<ShapeHitbox>()) {
      pick = child;
      break;
    }
    if (pick == null) return null;
    return collisionFamilyOf(pick) == CollisionFamily.terrain
        ? CollisionFamily.terrain
        : null;
  }

  @override
  void onMount() {
    super.onMount();
    debugPrint('[EntityPhysicsMixin] mounted: $runtimeType');
  }
}
