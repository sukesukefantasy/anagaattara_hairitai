import 'dart:ui' show Offset, Rect;

import 'package:flame/components.dart';

import 'body_terrain_probes.dart';
import 'grid_terrain_field.dart';
import 'stamp_terrain_field.dart';
import 'terrain_collision_samples.dart';
import 'terrain_field.dart';

/// グリッド掘削と経路スタンプの合成。どちらかで通行可能なら岩は無い。
class CompositeTerrainField implements TerrainField {
  final Rect undergroundBounds;
  final GridTerrainField grid;
  final StampTerrainField stamps;

  CompositeTerrainField({
    required this.undergroundBounds,
    required this.grid,
    required this.stamps,
  });

  @override
  bool isBlocked(Rect worldAabb) {
    if (!worldAabb.overlaps(undergroundBounds)) {
      return false;
    }
    for (final sample in TerrainCollisionSamples.cornerAndCenterProbePoints(worldAabb)) {
      if (_isRockAt(sample)) return true;
    }
    return false;
  }

  /// ワールド座標が通行可能か（グリッド掘削またはスタンプ内）。
  bool isPassablePoint(Vector2 worldPoint) => !_isRockAt(worldPoint);

  /// 四隅＋中心がすべて通行可能か。
  bool areCornersPassable(Rect worldAabb) => !isBlocked(worldAabb);

  /// 前方3プローブがすべて岩のときだけ壁（段差・天井ギザでは止めない）。
  @override
  bool isBlockedHorizontal(Rect worldAabb, {int moveSign = 0}) {
    if (!worldAabb.overlaps(undergroundBounds)) {
      return false;
    }
    if (moveSign != 0) {
      return BodyTerrainProbes.isWallAhead(
        aabb: worldAabb,
        terrain: this,
        intent: moveSign,
      );
    }
    return BodyTerrainProbes.isWallAhead(
          aabb: worldAabb,
          terrain: this,
          intent: -1,
        ) ||
        BodyTerrainProbes.isWallAhead(
          aabb: worldAabb,
          terrain: this,
          intent: 1,
        );
  }

  bool _isRockAt(Vector2 worldPoint) {
    if (!undergroundBounds.contains(Offset(worldPoint.x, worldPoint.y))) {
      return false;
    }
    if (stamps.containsPoint(worldPoint)) return false;
    return true;
  }

  @override
  void carveCircle(Vector2 center, double radius) {
    stamps.carveCircleDeduped(center, radius);
  }

  @override
  void carveCapsule(Vector2 a, Vector2 b, double radius) {
    stamps.carveCapsule(a, b, radius);
  }
}
