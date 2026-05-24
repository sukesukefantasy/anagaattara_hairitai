import 'dart:math';
import 'dart:ui' show Offset, Rect;

import 'package:flame/components.dart';

import 'body_terrain_probes.dart';
import 'polygon_terrain_math.dart';
import 'terrain_collision_samples.dart';
import 'terrain_field.dart';

/// 円スタンプ列による通行可能領域（経路ベース掘削）。
class StampTerrainField implements TerrainField {
  final Rect undergroundBounds;
  final List<CarveStamp> stamps;

  static const int maxStamps = 1800;
  static const double bucketSize = 64.0;

  final Map<int, Set<int>> _bucketToStampIndices = {};

  StampTerrainField({
    required this.undergroundBounds,
    required this.stamps,
  }) {
    _rebuildSpatialIndex();
  }

  int _bucketKey(int gx, int gy) => Object.hash(gx, gy);

  void _forEachBucketInBounds(Rect bounds, void Function(int gx, int gy) fn) {
    final minGx = (bounds.left / bucketSize).floor();
    final maxGx = (bounds.right / bucketSize).floor();
    final minGy = (bounds.top / bucketSize).floor();
    final maxGy = (bounds.bottom / bucketSize).floor();
    for (var gy = minGy; gy <= maxGy; gy++) {
      for (var gx = minGx; gx <= maxGx; gx++) {
        fn(gx, gy);
      }
    }
  }

  List<int> _collectIndicesInBounds(Rect bounds) {
    final seen = <int>{};
    final result = <int>[];
    _forEachBucketInBounds(bounds, (gx, gy) {
      final indices = _bucketToStampIndices[_bucketKey(gx, gy)];
      if (indices == null) return;
      for (final i in indices) {
        if (seen.add(i)) result.add(i);
      }
    });
    return result;
  }

  void _rebuildSpatialIndex() {
    _bucketToStampIndices.clear();
    for (var i = 0; i < stamps.length; i++) {
      _indexStampAt(i);
    }
  }

  void _indexStampAt(int index) {
    _forEachBucketInBounds(stamps[index].bounds, (gx, gy) {
      _bucketToStampIndices
          .putIfAbsent(_bucketKey(gx, gy), () => <int>{})
          .add(index);
    });
  }

  Iterable<int> _candidateIndicesNear(Vector2 center, double radius) sync* {
    final bounds = Rect.fromLTWH(
      center.x - radius - bucketSize,
      center.y - radius - bucketSize,
      (radius + bucketSize) * 2,
      (radius + bucketSize) * 2,
    );
    for (final i in _collectIndicesInBounds(bounds)) {
      yield i;
    }
  }

  Iterable<int> _candidateIndicesAtPoint(Vector2 p) sync* {
    final gx = (p.x / bucketSize).floor();
    final gy = (p.y / bucketSize).floor();
    final seen = <int>{};
    for (var dy = -1; dy <= 1; dy++) {
      for (var dx = -1; dx <= 1; dx++) {
        final indices = _bucketToStampIndices[_bucketKey(gx + dx, gy + dy)];
        if (indices == null) continue;
        for (final i in indices) {
          if (seen.add(i)) yield i;
        }
      }
    }
  }

  Iterable<int> _candidateIndicesOverlapping(Rect worldRect) sync* {
    for (final i in _collectIndicesInBounds(worldRect)) {
      yield i;
    }
  }

  bool _stampContainsPoint(CarveStamp s, Vector2 p) {
    if (s.kind == CarveStampKind.circle) {
      if (p.x < s.x - s.radius || p.x > s.x + s.radius) return false;
      if (p.y < s.y - s.radius || p.y > s.y + s.radius) return false;
      final dx = p.x - s.x;
      final dy = p.y - s.y;
      return dx * dx + dy * dy <= s.radius * s.radius;
    }
    final bounds = s.bounds;
    if (p.x < bounds.left ||
        p.x > bounds.right ||
        p.y < bounds.top ||
        p.y > bounds.bottom) {
      return false;
    }
    return PolygonTerrainMath.containsPoint(s.worldVertices(), p);
  }

  /// 既に同程度掘られていれば false（重複スタンプを増やさない）。
  bool carveCircleDeduped(Vector2 center, double radius) {
    final mergeDist = radius * 0.35;
    final mergeDist2 = mergeDist * mergeDist;
    for (final i in _candidateIndicesNear(center, radius)) {
      final s = stamps[i];
      if (s.kind == CarveStampKind.polygon) continue;
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
    _ensureStampCapacity();
    stamps.add(
      CarveStamp.circle(x: center.x, y: center.y, radius: radius),
    );
    _indexStampAt(stamps.length - 1);
    return true;
  }

  void _ensureStampCapacity() {
    if (stamps.length >= maxStamps) {
      _pruneOldest(stamps.length ~/ 8);
    }
  }

  void _pruneOldest(int count) {
    if (count <= 0 || stamps.isEmpty) return;
    stamps.removeRange(0, count.clamp(1, stamps.length));
    _rebuildSpatialIndex();
  }

  bool containsPoint(Vector2 p) {
    for (final i in _candidateIndicesAtPoint(p)) {
      if (_stampContainsPoint(stamps[i], p)) {
        return true;
      }
    }
    return false;
  }

  /// [worldRect] と交差するスタンプを削除。1つでも削除したら true。
  bool removeStampsOverlapping(Rect worldRect) {
    final before = stamps.length;
    stamps.removeWhere((s) => s.bounds.overlaps(worldRect));
    if (stamps.length == before) return false;
    _rebuildSpatialIndex();
    return true;
  }

  Iterable<CarveStamp> stampsOverlapping(Rect worldAabb) sync* {
    final seen = <int>{};
    for (final i in _candidateIndicesOverlapping(worldAabb)) {
      if (!seen.add(i)) continue;
      final s = stamps[i];
      if (s.bounds.overlaps(worldAabb)) yield s;
    }
  }

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

  @override
  bool isBlocked(Rect worldAabb) {
    if (!worldAabb.overlaps(undergroundBounds)) {
      return false;
    }
    for (final sample
        in TerrainCollisionSamples.cornerAndCenterProbePoints(worldAabb)) {
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

  static Iterable<Vector2> samplePoints(Rect r) =>
      TerrainCollisionSamples.cornerAndCenterProbePoints(r);
}
