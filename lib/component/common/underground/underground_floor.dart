import 'dart:ui' show Offset, Rect;

import 'package:flame/components.dart';

import '../physics/physics_body_queries.dart';
import '../terrain/stamp_terrain_field.dart';
import 'placed_floor.dart';

/// [UnderGround] の床板配置・判定ロジック。
mixin UnderGroundFloor on PositionComponent {
  static const double floorSlabWidth = 64;
  static const double floorSlabHeight = 8;
  /// 横並び配置時の端スナップ距離。
  static const double floorEdgeSnapRadius = 20;

  List<PlacedFloor> get placedFloors;
  StampTerrainField get stampFieldForFloor;
  Rect get undergroundBoundsForFloor;

  Iterable<Rect> floorSlabs() sync* {
    for (final floor in placedFloors) {
      yield floor.slabRect;
    }
  }

  /// 近傍床の左右端へスナップ（横並び用。縦積みでは Y を揃えない）。
  Vector2 snapFloorPreviewCenter(
    Vector2 raw,
    double previewHalfWidth,
    double previewHalfHeight,
  ) {
    var bestDist = floorEdgeSnapRadius;
    double? snappedX;
    double? snappedY;

    for (final floor in placedFloors) {
      final slab = floor.slabRect;
      // surfaceY = 上面。中心 Y = 上面 + halfHeight
      final rowCenterY = floor.surfaceY + previewHalfHeight;

      if ((raw.y - rowCenterY).abs() > floorSlabHeight * 1.5) {
        continue;
      }

      final attachRight = slab.right + previewHalfWidth;
      final distRight = (raw.x - attachRight).abs();
      if (distRight < bestDist) {
        bestDist = distRight;
        snappedX = attachRight;
        snappedY = rowCenterY;
      }

      final attachLeft = slab.left - previewHalfWidth;
      final distLeft = (raw.x - attachLeft).abs();
      if (distLeft < bestDist) {
        bestDist = distLeft;
        snappedX = attachLeft;
        snappedY = rowCenterY;
      }
    }

    if (snappedX != null && snappedY != null) {
      return Vector2(snappedX, snappedY);
    }
    return raw;
  }

  /// 同じ高さで左右端が接続できる既存床があるか。
  PlacedFloor? horizontallyAdjacentFloor(Rect slabRect) {
    const yTol = 2.0;
    const xTol = floorEdgeSnapRadius + 2;

    for (final floor in placedFloors) {
      final other = floor.slabRect;
      if ((slabRect.top - other.top).abs() > yTol) continue;

      final gapRight = (slabRect.left - other.right).abs();
      final gapLeft = (other.left - slabRect.right).abs();
      if (gapRight <= xTol || gapLeft <= xTol) {
        return floor;
      }
    }
    return null;
  }

  bool canPlaceFloor(Rect slabRect, {Rect? ignorePlayerOverlap}) {
    if (!undergroundBoundsForFloor.contains(Offset(slabRect.left, slabRect.top)) ||
        !undergroundBoundsForFloor.contains(Offset(slabRect.right, slabRect.bottom))) {
      return false;
    }

    if (_overlapsExistingFloorTooMuch(slabRect)) return false;

    final adjacent = horizontallyAdjacentFloor(slabRect);
    if (adjacent != null) {
      // 隣接接合時: 上面が空気なら OK（下は隣床が支える）
      return _topIsDugAir(slabRect);
    }

    if (!_topIsDugAir(slabRect)) return false;
    if (!_hasSupportBelow(slabRect)) return false;

    return true;
  }

  bool _topIsDugAir(Rect slabRect) {
    for (final x in _horizontalProbeXs(slabRect)) {
      final probe = Vector2(x, slabRect.top - 2);
      if (!stampFieldForFloor.containsPoint(probe)) {
        return false;
      }
    }
    return true;
  }

  bool _hasSupportBelow(Rect slabRect) {
    for (final x in _horizontalProbeXs(slabRect)) {
      if (!_hasSupportAt(Vector2(x, slabRect.bottom + 2))) {
        return false;
      }
    }
    return true;
  }

  bool _hasSupportAt(Vector2 worldPoint) {
    for (final floor in placedFloors) {
      final slab = floor.slabRect;
      if (worldPoint.x >= slab.left &&
          worldPoint.x <= slab.right &&
          worldPoint.y >= slab.top - 1 &&
          worldPoint.y <= slab.bottom + 2) {
        return true;
      }
    }
    if (!undergroundBoundsForFloor.contains(Offset(worldPoint.x, worldPoint.y))) {
      return false;
    }
    return !stampFieldForFloor.containsPoint(worldPoint);
  }

  bool _overlapsExistingFloorTooMuch(Rect slabRect) {
    final slabArea = slabRect.width * slabRect.height;
    if (slabArea <= 0) return true;

    for (final floor in placedFloors) {
      if (!slabRect.overlaps(floor.slabRect)) continue;
      // 端同士の接合（面積重なりほぼなし）は許可
      final intersection = slabRect.intersect(floor.slabRect);
      if (intersection.width <= 0 || intersection.height <= 0) continue;
      if (intersection.width * intersection.height <= 1) continue;
      if (intersection.width * intersection.height > slabArea * 0.15) {
        return true;
      }
    }
    return false;
  }

  Iterable<double> _horizontalProbeXs(Rect slabRect) sync* {
    yield slabRect.left + 4;
    yield slabRect.center.dx;
    yield slabRect.right - 4;
  }

  bool canPlaceFloorForPlayer(Rect slabRect, PositionComponent player) {
    final playerAabb = PhysicsBodyQueries.physicsAabb(player);
    if (playerAabb.overlaps(slabRect)) return false;
    return canPlaceFloor(slabRect);
  }
}
