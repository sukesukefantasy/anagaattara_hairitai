import 'dart:math';
import 'dart:ui' show Offset, Rect;

import 'package:flame/components.dart';

import 'terrain_field.dart';

/// 円スタンプ列による通行可能領域（経路ベース掘削）。
class StampTerrainField implements TerrainField {
  final Rect undergroundBounds;
  final List<CarveStamp> stamps;

  static const int maxStamps = 1800;

  StampTerrainField({
    required this.undergroundBounds,
    required this.stamps,
  });

  /// 既に同程度掘られていれば false（重複スタンプを増やさない）。
  bool carveCircleDeduped(Vector2 center, double radius) {
    final mergeDist = radius * 0.35;
    final mergeDist2 = mergeDist * mergeDist;
    for (final s in stamps) {
      final dx = center.x - s.x;
      final dy = center.y - s.y;
      final reach = s.radius + radius * 0.35;
      if (dx * dx + dy * dy < reach * reach * 0.25) {
        return false;
      }
      if (dx * dx + dy * dy < mergeDist2) {
        return false;
      }
    }
    if (stamps.length >= maxStamps) {
      _pruneOldest(stamps.length ~/ 8);
    }
    stamps.add(CarveStamp(x: center.x, y: center.y, radius: radius));
    return true;
  }

  void _pruneOldest(int count) {
    if (count <= 0 || stamps.isEmpty) return;
    stamps.removeRange(0, count.clamp(1, stamps.length));
  }

  bool containsPoint(Vector2 p) {
    for (final s in stamps) {
      if (p.x < s.x - s.radius || p.x > s.x + s.radius) continue;
      if (p.y < s.y - s.radius || p.y > s.y + s.radius) continue;
      final dx = p.x - s.x;
      final dy = p.y - s.y;
      if (dx * dx + dy * dy <= s.radius * s.radius) {
        return true;
      }
    }
    return false;
  }

  Iterable<CarveStamp> stampsOverlapping(Rect worldAabb) sync* {
    for (final s in stamps) {
      if (s.x + s.radius < worldAabb.left ||
          s.x - s.radius > worldAabb.right ||
          s.y + s.radius < worldAabb.top ||
          s.y - s.radius > worldAabb.bottom) {
        continue;
      }
      yield s;
    }
  }

  @override
  bool isBlocked(Rect worldAabb) {
    if (!worldAabb.overlaps(undergroundBounds)) {
      return false;
    }
    for (final sample in samplePoints(worldAabb)) {
      if (undergroundBounds.contains(Offset(sample.x, sample.y)) &&
          !containsPoint(sample)) {
        return true;
      }
    }
    return false;
  }

  @override
  void carveCircle(Vector2 center, double radius) {
    carveCircleDeduped(center, radius);
  }

  @override
  void carveCapsule(Vector2 a, Vector2 b, double radius) {
    final dx = b.x - a.x;
    final dy = b.y - a.y;
    final len = sqrt(dx * dx + dy * dy);
    if (len < 1e-3) {
      carveCircleDeduped(a, radius);
      return;
    }
    final step = radius * 0.55;
    final n = (len / step).ceil().clamp(1, 24);
    for (var i = 0; i <= n; i++) {
      final t = i / n;
      carveCircleDeduped(
        Vector2(a.x + dx * t, a.y + dy * t),
        radius,
      );
    }
  }

  static Iterable<Vector2> samplePoints(Rect r) sync* {
    yield Vector2(r.left, r.top);
    yield Vector2(r.right, r.top);
    yield Vector2(r.left, r.bottom);
    yield Vector2(r.right, r.bottom);
    yield Vector2(r.center.dx, r.center.dy);
  }
}
