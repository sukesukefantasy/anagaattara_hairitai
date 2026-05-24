import 'dart:ui' show Offset, Rect;

import 'package:flame/components.dart';

import '../underground/underground.dart';
import 'terrain_field.dart';

/// 64px グリッドの [dugAreas] に基づく地形。セーブ互換用。
class GridTerrainField implements TerrainField {
  final Rect undergroundBounds;
  final double cellSize;
  final Set<Vector2> dugCells;
  final Vector2 Function(Vector2 worldPos) cellTopLeftOf;

  GridTerrainField({
    required this.undergroundBounds,
    required this.dugCells,
    required this.cellTopLeftOf,
    this.cellSize = UnderGround.digAreaSize,
  });

  @override
  bool isBlockedHorizontal(Rect worldAabb, {int moveSign = 0}) =>
      isBlocked(worldAabb);

  @override
  bool isBlocked(Rect worldAabb) {
    if (!worldAabb.overlaps(undergroundBounds)) {
      return false;
    }

    final minGx =
        ((worldAabb.left - undergroundBounds.left) / cellSize).floor();
    final maxGx =
        ((worldAabb.right - undergroundBounds.left) / cellSize).floor();
    final minGy =
        ((worldAabb.top - undergroundBounds.top) / cellSize).floor();
    final maxGy =
        ((worldAabb.bottom - undergroundBounds.top) / cellSize).floor();

    for (var gy = minGy; gy <= maxGy; gy++) {
      for (var gx = minGx; gx <= maxGx; gx++) {
        final cellWorld = Vector2(
          undergroundBounds.left + gx * cellSize,
          undergroundBounds.top + gy * cellSize,
        );
        if (!undergroundBounds.contains(Offset(cellWorld.x, cellWorld.y))) {
          continue;
        }
        final key = cellTopLeftOf(cellWorld);
        if (!dugCells.contains(key)) {
          return true;
        }
      }
    }
    return false;
  }

  @override
  void carveCircle(Vector2 center, double radius) {
    final topLeft = cellTopLeftOf(center);
    dugCells.add(topLeft);
  }

  bool isCellDug(Vector2 worldPoint) =>
      dugCells.contains(cellTopLeftOf(worldPoint));

  @override
  void carveCapsule(Vector2 a, Vector2 b, double radius) {
    final dist = (b - a).length;
    final steps = dist < 1 ? 1 : (dist / (radius * 0.45)).ceil().clamp(1, 48);
    for (var i = 0; i <= steps; i++) {
      final t = i / steps;
      carveCircle(a + (b - a) * t, radius);
    }
  }
}
