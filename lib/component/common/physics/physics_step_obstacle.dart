import 'dart:math' show min, max;
import 'dart:ui' show Rect;

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';

/// ワールド AABB・乗り越え対象としての寸法を共有するヘルパ。
abstract final class PhysicsStepQueries {
  static double axisOverlap(
    double aMin,
    double aMax,
    double bMin,
    double bMax,
  ) =>
      min(aMax, bMax) - max(aMin, bMin);

  static Rect absoluteAabb(PositionComponent c) {
    final abs = c.absolutePosition;
    final tlx = abs.x - c.anchor.x * c.size.x;
    final tly = abs.y - c.anchor.y * c.size.y;
    return Rect.fromLTWH(tlx, tly, c.size.x, c.size.y);
  }

  /// ヒットボックスなら親の位置コンポーネントへ（それ以外はそのまま）。
  static PositionComponent solidRoot(PositionComponent c) {
    if (c is ShapeHitbox && c.parent is PositionComponent) {
      return c.parent! as PositionComponent;
    }
    return c;
  }
}

/// [EntityPhysicsMixin] やプレイヤーが「低い障害物」として乗り越える対象にするマーカー。
///
/// [DestructibleObject]・[Station] など静的オブジェクトに付与する。
/// （オブジェクト側に [EntityPhysicsMixin] を付けると固体として検知されなくなるため、このミックスインを使う）
mixin PhysicsStepObstacleMixin on PositionComponent {
  /// 段差としての高さ（エンティティの `size.y / 2` 以下なら乗り越え可能）
  double get physicsStepClearHeight => PhysicsStepQueries.absoluteAabb(this).height;

  /// 足場としての表面上端のワールド Y（上方向ほど値が小さい座標系）
  double get physicsStepSurfaceTopWorldY =>
      PhysicsStepQueries.absoluteAabb(this).top;
}
