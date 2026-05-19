import 'dart:ui' show Offset, Rect;

import 'package:flame/components.dart';

import 'grid_terrain_field.dart';
import 'stamp_terrain_field.dart';
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
    for (final sample in StampTerrainField.samplePoints(worldAabb)) {
      if (!undergroundBounds.contains(Offset(sample.x, sample.y))) {
        continue;
      }
      if (grid.isCellDug(sample)) continue;
      if (stamps.containsPoint(sample)) continue;
      return true;
    }
    return false;
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
